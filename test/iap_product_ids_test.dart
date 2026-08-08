import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/features/billing/iap_service.dart';

void main() {
  group('IAP product IDs (Play + ASC parity)', () {
    test('Pro uses v2 id (ASC reuse ban)', () {
      expect(kIapProductPro, 'lotlot_pro_monthly_v2');
    });

    test('Premium monthly id', () {
      expect(kIapProductPremium, 'lotlot_premium_monthly');
    });

    test('default query set contains both store SKUs', () {
      expect(kDefaultIapProductIds, containsAll([kIapProductPro, kIapProductPremium]));
      expect(kDefaultIapProductIds.length, 2);
    });
  });
}
