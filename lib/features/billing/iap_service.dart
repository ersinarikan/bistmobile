import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Store ürün ID’leri — guide §9.4 / config fallback.
const kIapProductPro = 'lotlot_pro_monthly';
const kIapProductPremium = 'lotlot_premium_monthly';
const kDefaultIapProductIds = {kIapProductPro, kIapProductPremium};

class IapPurchaseResult {
  const IapPurchaseResult({
    required this.productId,
    required this.platform,
    this.signedTransaction,
    this.purchaseToken,
  });

  final String productId;
  final String platform; // apple | google
  final String? signedTransaction;
  final String? purchaseToken;
}

/// Thin wrapper around `in_app_purchase` — entitlement sunucuda.
class IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _purchaseWaiters = <String, Completer<PurchaseDetails>>{};

  bool available = false;
  String? lastError;

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) {
      lastError = 'Mağaza satın alma bu cihazda kullanılamıyor.';
      return;
    }
    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        lastError = e.toString();
        for (final c in _purchaseWaiters.values) {
          if (!c.isCompleted) c.completeError(e);
        }
        _purchaseWaiters.clear();
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<Map<String, ProductDetails>> queryProducts(Set<String> ids) async {
    if (!available) return {};
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      lastError = response.error!.message;
    }
    return {for (final p in response.productDetails) p.id: p};
  }

  /// Satın alma; tamamlanınca [PurchaseDetails] döner.
  Future<PurchaseDetails> buy(ProductDetails product) async {
    if (!available) {
      throw StateError(lastError ?? 'Mağaza kullanılamıyor');
    }
    final completer = Completer<PurchaseDetails>();
    _purchaseWaiters[product.id] = completer;

    final param = PurchaseParam(productDetails: product);
    // Abonelikler non-consumable / auto-renewing subscription olarak gelir.
    final ok = await _iap.buyNonConsumable(purchaseParam: param);
    if (!ok) {
      _purchaseWaiters.remove(product.id);
      throw StateError('Satın alma başlatılamadı');
    }
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _purchaseWaiters.remove(product.id);
        throw TimeoutException('Satın alma zaman aşımı');
      },
    );
  }

  Future<List<PurchaseDetails>> restore() async {
    if (!available) return [];
    final collected = <PurchaseDetails>[];
    final done = Completer<List<PurchaseDetails>>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    Timer? settle;
    sub = _iap.purchaseStream.listen((list) {
      for (final p in list) {
        if (p.status == PurchaseStatus.restored ||
            p.status == PurchaseStatus.purchased) {
          collected.add(p);
        }
      }
      settle?.cancel();
      settle = Timer(const Duration(milliseconds: 900), () {
        if (!done.isCompleted) done.complete(List.of(collected));
      });
    });
    try {
      await _iap.restorePurchases();
      return await done.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => List.of(collected),
      );
    } finally {
      settle?.cancel();
      await sub.cancel();
    }
  }

  Future<void> complete(PurchaseDetails details) async {
    if (details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  IapPurchaseResult? toVerifyPayload(PurchaseDetails details) {
    final productId = details.productID;
    if (productId.isEmpty) return null;
    final serverData = details.verificationData.serverVerificationData;
    if (serverData.isEmpty) return null;

    if (Platform.isIOS) {
      return IapPurchaseResult(
        productId: productId,
        platform: 'apple',
        signedTransaction: serverData,
      );
    }
    if (Platform.isAndroid) {
      return IapPurchaseResult(
        productId: productId,
        platform: 'google',
        purchaseToken: serverData,
      );
    }
    return null;
  }

  String get storePlatform {
    if (Platform.isIOS) return 'apple';
    if (Platform.isAndroid) return 'google';
    return 'unknown';
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) continue;
      final waiter = _purchaseWaiters.remove(p.productID);
      if (waiter == null || waiter.isCompleted) continue;
      if (p.status == PurchaseStatus.error) {
        waiter.completeError(
          StateError(p.error?.message ?? 'Satın alma hatası'),
        );
      } else if (p.status == PurchaseStatus.canceled) {
        waiter.completeError(StateError('Satın alma iptal edildi'));
      } else {
        waiter.complete(p);
      }
    }
  }
}
