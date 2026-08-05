import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/api/api_client.dart';
import '../auth/session_controller.dart';
import 'iap_service.dart';

/// IAP config + satın alma / restore → verify → `/me`.
class BillingController extends ChangeNotifier {
  BillingController({
    required ApiClient apiClient,
    required this._session,
    IapService? iapService,
  })  : _api = apiClient,
        _iap = iapService ?? IapService();

  final ApiClient _api;
  final SessionController _session;
  final IapService _iap;

  bool loadingConfig = false;
  bool busy = false;
  String? error;
  String? lastErrorCode;

  bool iapEnabled = false;
  bool verifyReady = false;
  bool applePlatform = false;
  bool googlePlayPlatform = false;
  Map<String, String> productTiers = {
    kIapProductPro: 'pro',
    kIapProductPremium: 'premium',
  };

  Map<String, ProductDetails> storeProducts = {};
  bool storeAvailable = false;

  /// Eşzamanlı restore → tek API POST (single-flight).
  Future<bool>? _restoreFlight;

  bool get canPurchase =>
      iapEnabled && verifyReady && storeAvailable && _platformOk;

  /// Paywall / soft gate: satın alma kilitliyken kullanıcı mesajı (çökme yok).
  String get purchaseBlockedReason => error ?? _disabledMessage();

  bool get _platformOk {
    final p = _iap.storePlatform;
    if (p == 'apple') return applePlatform;
    if (p == 'google') return googlePlayPlatform;
    return false;
  }

  ProductDetails? productFor(String id) => storeProducts[id];

  /// StoreKit/Play bu ürünü döndürdü mü (fiyat satırı ve satın alma için).
  bool hasStoreProduct(String productId) => storeProducts.containsKey(productId);

  String? priceLabel(String productId) => storeProducts[productId]?.price;

  String tierForProduct(String productId) =>
      productTiers[productId] ?? 'pro';

  Future<void> load() async {
    loadingConfig = true;
    error = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      await _iap.init();
      storeAvailable = _iap.available;

      final raw = await _api.fetchIapConfig();
      final iap = raw['iap'];
      if (iap is Map) {
        iapEnabled = iap['enabled'] == true;
        verifyReady = iap['verify_ready'] == true;
        final platforms = iap['platforms'];
        if (platforms is Map) {
          applePlatform = platforms['apple'] == true;
          googlePlayPlatform = platforms['google_play'] == true;
        }
        final products = iap['products'];
        if (products is Map && products.isNotEmpty) {
          productTiers = {
            for (final e in products.entries)
              e.key.toString(): e.value.toString(),
          };
        }
      }

      if (storeAvailable && productTiers.isNotEmpty) {
        storeProducts = await _iap.queryProducts(productTiers.keys.toSet());
      }
    } on ApiException catch (e) {
      error = e.message;
      lastErrorCode = e.errorCode;
    } catch (e) {
      error = e.toString();
    } finally {
      loadingConfig = false;
      notifyListeners();
    }
  }

  Future<bool> purchase(String productId) async {
    if (busy) return false;
    if (!canPurchase) {
      error = _disabledMessage();
      notifyListeners();
      return false;
    }
    final product = storeProducts[productId];
    if (product == null) {
      error = 'Ürün mağazada bulunamadı. Daha sonra tekrar deneyin.';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    lastErrorCode = null;
    notifyListeners();
    PurchaseDetails? details;
    try {
      details = await _iap.buy(product);
      final payload = _iap.toVerifyPayload(details);
      if (payload == null) {
        error = 'Satın alma doğrulama verisi alınamadı.';
        return false;
      }
      try {
        await _api.verifyIap(
          platform: payload.platform,
          productId: payload.productId,
          signedTransaction: payload.signedTransaction,
          purchaseToken: payload.purchaseToken,
        );
      } on ApiException catch (e) {
        // 409 already_subscribed: mağaza işlemini yine bitirmeliyiz (yoksa kuyruk kilitlenir).
        if (e.errorCode == 'already_subscribed' || e.statusCode == 409) {
          await _session.refreshMe();
          error = null;
          lastErrorCode = e.errorCode;
          return true;
        }
        error = _friendlyBillingError(e);
        lastErrorCode = e.errorCode;
        return false;
      }
      await _session.refreshMe();
      return true;
    } on ApiException catch (e) {
      error = _friendlyBillingError(e);
      lastErrorCode = e.errorCode;
      return false;
    } on PlatformException catch (e) {
      error = _friendlyPlatformError(e);
      return false;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('iptal')) {
        error = null;
      } else {
        error = msg
            .replaceFirst('Bad state: ', '')
            .replaceFirst('StateError: ', '')
            .replaceFirst('Exception: ', '')
            .replaceFirst('TimeoutException: ', '');
      }
      return false;
    } finally {
      // Verify başarısız olsa bile StoreKit kuyruğunu boşalt (pending → loader kilidi).
      if (details != null) {
        try {
          await _iap.complete(details);
        } catch (_) {/* ignore */}
      }
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() {
    return _restoreFlight ??= _restorePurchasesOnce().whenComplete(() {
      _restoreFlight = null;
    });
  }

  Future<bool> _restorePurchasesOnce() async {
    if (busy) return false;
    if (!storeAvailable) {
      error = _iap.lastError ?? 'Mağaza kullanılamıyor.';
      notifyListeners();
      return false;
    }
    if (!iapEnabled) {
      error = _disabledMessage();
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      final list = await _iap.restore();
      if (list.isEmpty) {
        error = 'Geri yüklenecek abonelik bulunamadı.';
        return false;
      }

      final platform = _iap.storePlatform;
      if (platform == 'apple') {
        // Aynı JWS birden fazla gelirse tek POST.
        final jws = <String>{};
        for (final p in list) {
          final payload = _iap.toVerifyPayload(p);
          if (payload?.signedTransaction != null) {
            jws.add(payload!.signedTransaction!);
          }
          await _iap.complete(p);
        }
        if (jws.isEmpty) {
          error = 'Geri yükleme doğrulama verisi alınamadı.';
          return false;
        }
        await _api.restoreIap(
          platform: 'apple',
          signedTransactions: jws.toList(),
        );
      } else if (platform == 'google') {
        final seen = <String>{};
        final purchases = <Map<String, String>>[];
        for (final p in list) {
          final payload = _iap.toVerifyPayload(p);
          final token = payload?.purchaseToken;
          if (token == null || !seen.add(token)) continue;
          purchases.add({
            'product_id': payload!.productId,
            'purchase_token': token,
          });
          await _iap.complete(p);
        }
        if (purchases.isEmpty) {
          error = 'Geri yükleme doğrulama verisi alınamadı.';
          return false;
        }
        await _api.restoreIap(platform: 'google', purchases: purchases);
      } else {
        error = 'Bu platformda geri yükleme desteklenmiyor.';
        return false;
      }

      await _session.refreshMe();
      return true;
    } on ApiException catch (e) {
      error = _friendlyBillingError(e);
      lastErrorCode = e.errorCode;
      return false;
    } on PlatformException catch (e) {
      error = _friendlyPlatformError(e);
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _friendlyPlatformError(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    if (code.contains('duplicate') || msg.contains('pending transaction')) {
      return 'Bekleyen bir mağaza işlemi var. '
          'Aboneliği geri yükle’yi deneyin veya uygulamayı kapatıp açın.';
    }
    if (code.contains('cancel') || msg.contains('cancel')) {
      return 'Satın alma iptal edildi';
    }
    if (msg.isNotEmpty) return msg;
    return 'Mağaza işlemi başarısız ($code)';
  }

  String _disabledMessage() {
    if (!iapEnabled) {
      return 'Uygulama içi abonelik şu an kapalı. '
          'Web’den alınmış planınız varsa giriş yaparak kullanabilirsiniz.';
    }
    if (!verifyReady) {
      return 'Satın alma doğrulama servisi henüz hazır değil. Lütfen sonra deneyin.';
    }
    if (!storeAvailable) {
      return _iap.lastError ?? 'Mağaza bu cihazda kullanılamıyor.';
    }
    if (!_platformOk) {
      return 'Bu mağazada uygulama içi satın alma henüz etkin değil.';
    }
    return 'Satın alma şu an kullanılamıyor.';
  }

  String _friendlyBillingError(ApiException e) {
    switch (e.errorCode) {
      case 'billing_disabled':
        return 'Uygulama içi abonelik kapalı.';
      case 'iap_provider_unavailable':
        return 'Mağaza doğrulama servisi geçici olarak kullanılamıyor.';
      case 'product_mismatch':
        return 'Ürün tanınmadı. Destek ile iletişime geçin.';
      case 'already_subscribed':
        return 'Bu plan zaten aktif.';
      case 'receipt_owned_by_other_account':
        return 'Bu mağaza aboneliği başka bir LOTLOT hesabına bağlı.';
      case 'invalid_receipt':
        return 'Satın alma doğrulanamadı. Geri yüklemeyi deneyin.';
      case 'google_acknowledge_failed':
        return 'Google onaylama başarısız. Biraz sonra tekrar deneyin.';
      default:
        return e.message;
    }
  }

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }
}
