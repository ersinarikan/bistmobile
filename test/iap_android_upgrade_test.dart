import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lotlotnet_mobile/features/billing/iap_service.dart';

GooglePlayPurchaseDetails _gp({
  required String productId,
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  final wrapper = PurchaseWrapper(
    orderId: 'order-$productId',
    packageName: 'com.lotlot.lotlotnet_mobile',
    purchaseTime: 1,
    signature: 'sig',
    products: [productId],
    purchaseToken: 'token-$productId',
    isAutoRenewing: true,
    originalJson: '{}',
    isAcknowledged: true,
    purchaseState: PurchaseStateWrapper.purchased,
  );
  return GooglePlayPurchaseDetails(
    purchaseID: wrapper.orderId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: wrapper.originalJson,
      serverVerificationData: wrapper.purchaseToken,
      source: 'google_play',
    ),
    transactionDate: '1',
    billingClientPurchase: wrapper,
    status: status,
  );
}

void main() {
  group('findAndroidUpgradeOldPurchase', () {
    test('picks Pro when targeting Premium', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPremium,
        pastPurchases: [_gp(productId: kIapProductPro)],
      );
      expect(old?.productID, kIapProductPro);
    });

    test('picks Premium when targeting Pro', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPro,
        pastPurchases: [_gp(productId: kIapProductPremium)],
      );
      expect(old?.productID, kIapProductPremium);
    });

    test('skips same product id', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPremium,
        pastPurchases: [_gp(productId: kIapProductPremium)],
      );
      expect(old, isNull);
    });

    test('skips pending / error statuses', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPremium,
        pastPurchases: [
          _gp(productId: kIapProductPro, status: PurchaseStatus.pending),
        ],
      );
      expect(old, isNull);
    });

    test('ignores unknown product ids', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPremium,
        pastPurchases: [_gp(productId: 'other_sub')],
      );
      expect(old, isNull);
    });

    test('accepts restored status', () {
      final old = findAndroidUpgradeOldPurchase(
        targetProductId: kIapProductPremium,
        pastPurchases: [
          _gp(productId: kIapProductPro, status: PurchaseStatus.restored),
        ],
      );
      expect(old?.productID, kIapProductPro);
    });
  });
}
