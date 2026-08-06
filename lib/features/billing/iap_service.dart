import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Store ürün ID’leri — guide §9.4 / config fallback.
// ASC: eski `lotlot_pro_monthly` silindi — Product ID reuse yok; v2.
const kIapProductPro = 'lotlot_pro_monthly_v2';
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
  /// Listener açılmadan / buy beklemeden gelen (Apple unfinished queue) işlemler.
  final _unhandled = <String, PurchaseDetails>{};

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
    await _logStorefront('query');
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      lastError = response.error!.message;
    }
    return {for (final p in response.productDetails) p.id: p};
  }

  Future<void> _logStorefront(String phase) async {
    if (!Platform.isIOS) return;
    try {
      final sk2Country = await Storefront().countryCode();
      debugPrint(
        'IAP_PRICE_DEBUG phase=${phase}_storefront '
        'sk2_country=$sk2Country '
        'sk2=${InAppPurchaseStoreKitPlatform.isStoreKit2Enabled}',
      );
    } catch (e) {
      debugPrint('IAP_PRICE_DEBUG phase=${phase}_sk2_storefront_err err=$e');
    }
    try {
      final sk1 = await SKPaymentQueueWrapper().storefront();
      debugPrint(
        'IAP_PRICE_DEBUG phase=${phase}_storefront '
        'sk1_country=${sk1?.countryCode}',
      );
    } catch (e) {
      debugPrint('IAP_PRICE_DEBUG phase=${phase}_sk1_storefront_err err=$e');
    }
  }

  /// Satın alma; tamamlanınca [PurchaseDetails] döner.
  ///
  /// iOS’ta önceki oturumda `completePurchase` çağrılmadıysa StoreKit
  /// `storekit_duplicate_product_object` fırlatır — bekleyen işlemi alırız.
  Future<PurchaseDetails> buy(ProductDetails product) async {
    if (!available) {
      throw StateError(lastError ?? 'Mağaza kullanılamıyor');
    }

    PurchaseDetails? takeReady() {
      final existing = _unhandled.remove(product.id);
      if (existing != null &&
          (existing.status == PurchaseStatus.purchased ||
              existing.status == PurchaseStatus.restored)) {
        return existing;
      }
      return null;
    }

    final early = takeReady();
    if (early != null) return early;

    final completer = Completer<PurchaseDetails>();
    _purchaseWaiters[product.id] = completer;

    // Stream, waiter kaydından hemen önce gelmiş olabilir.
    final raced = takeReady();
    if (raced != null) {
      _purchaseWaiters.remove(product.id);
      return raced;
    }

    final param = PurchaseParam(productDetails: product);
    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (!ok) {
        _purchaseWaiters.remove(product.id);
        throw StateError('Satın alma başlatılamadı');
      }
    } on PlatformException catch (e) {
      if (_isPendingDuplicate(e)) {
        final pending = takeReady();
        if (pending != null) {
          _purchaseWaiters.remove(product.id);
          return pending;
        }
        try {
          await _iap.restorePurchases();
        } catch (_) {/* stream */}
        return _waitForPurchase(product.id, completer, const Duration(seconds: 45));
      }
      _purchaseWaiters.remove(product.id);
      rethrow;
    }

    return _waitForPurchase(product.id, completer, const Duration(seconds: 90));
  }

  /// Stream gecikirse `_unhandled` poll; Apple sheet bitti ama event kaçtıysa kurtarır.
  Future<PurchaseDetails> _waitForPurchase(
    String productId,
    Completer<PurchaseDetails> completer,
    Duration timeout,
  ) async {
    final poll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (completer.isCompleted) return;
      final ready = _unhandled.remove(productId);
      if (ready != null &&
          (ready.status == PurchaseStatus.purchased ||
              ready.status == PurchaseStatus.restored)) {
        _purchaseWaiters.remove(productId);
        if (!completer.isCompleted) completer.complete(ready);
      }
    });
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _purchaseWaiters.remove(productId);
          final late = _unhandled.remove(productId);
          if (late != null &&
              (late.status == PurchaseStatus.purchased ||
                  late.status == PurchaseStatus.restored)) {
            return late;
          }
          throw TimeoutException(
            'Satın alma tamamlanamadı. Aboneliği geri yükle’yi deneyin.',
          );
        },
      );
    } finally {
      poll.cancel();
    }
  }

  Future<List<PurchaseDetails>>? _restoreFlight;
  Completer<List<PurchaseDetails>>? _restoreDone;
  final _restoreBuffer = <PurchaseDetails>[];
  Timer? _restoreSettle;

  /// Tek uçuş: eşzamanlı restore aynı Future’ı paylaşır (çift API POST yok).
  Future<List<PurchaseDetails>> restore() {
    if (!available) return Future.value([]);
    return _restoreFlight ??= _restoreOnce().whenComplete(() {
      _restoreFlight = null;
    });
  }

  Future<List<PurchaseDetails>> _restoreOnce() async {
    _restoreSettle?.cancel();
    _restoreBuffer
      ..clear()
      ..addAll(
        _unhandled.values.where(
          (p) =>
              p.status == PurchaseStatus.restored ||
              p.status == PurchaseStatus.purchased,
        ),
      );
    _unhandled.clear();

    final done = Completer<List<PurchaseDetails>>();
    _restoreDone = done;

    void settleSoon() {
      _restoreSettle?.cancel();
      _restoreSettle = Timer(const Duration(milliseconds: 900), () {
        if (!done.isCompleted) {
          done.complete(_dedupePurchases(_restoreBuffer));
        }
        if (identical(_restoreDone, done)) {
          _restoreDone = null;
        }
      });
    }

    try {
      await _iap.restorePurchases();
      settleSoon();
      return await done.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => _dedupePurchases(_restoreBuffer),
      );
    } finally {
      _restoreSettle?.cancel();
      _restoreSettle = null;
      if (identical(_restoreDone, done)) {
        _restoreDone = null;
      }
    }
  }

  List<PurchaseDetails> _dedupePurchases(List<PurchaseDetails> list) {
    final seen = <String>{};
    final out = <PurchaseDetails>[];
    for (final p in list) {
      final key = p.purchaseID?.isNotEmpty == true
          ? p.purchaseID!
          : '${p.productID}:${p.verificationData.serverVerificationData}';
      if (seen.add(key)) out.add(p);
    }
    return out;
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

  bool _isPendingDuplicate(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    return code.contains('duplicate') ||
        msg.contains('pending transaction') ||
        msg.contains('duplicate');
  }

  void _onPurchases(List<PurchaseDetails> list) {
    var touchedRestore = false;
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) continue;

      final waiter = _purchaseWaiters.remove(p.productID);
      if (waiter != null && !waiter.isCompleted) {
        if (p.status == PurchaseStatus.error) {
          waiter.completeError(
            StateError(p.error?.message ?? 'Satın alma hatası'),
          );
        } else if (p.status == PurchaseStatus.canceled) {
          waiter.completeError(StateError('Satın alma iptal edildi'));
        } else {
          waiter.complete(p);
        }
        continue;
      }

      if (_restoreDone != null &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)) {
        _restoreBuffer.add(p);
        touchedRestore = true;
        continue;
      }

      // Buy/restore beklemiyorken gelen unfinished queue.
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _unhandled[p.productID] = p;
      } else if (p.pendingCompletePurchase) {
        unawaited(complete(p));
      }
    }
    if (touchedRestore && _restoreDone != null && !_restoreDone!.isCompleted) {
      _restoreSettle?.cancel();
      _restoreSettle = Timer(const Duration(milliseconds: 900), () {
        final done = _restoreDone;
        if (done != null && !done.isCompleted) {
          done.complete(_dedupePurchases(_restoreBuffer));
        }
        _restoreDone = null;
      });
    }
  }
}
