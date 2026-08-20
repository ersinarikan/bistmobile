import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/legal/legal_urls.dart';
import 'package:lotlotnet_mobile/core/theme/app_theme.dart';
import 'package:lotlotnet_mobile/features/billing/paywall_subscription_terms.dart';

void main() {
  test('paywall copy states monthly auto-renew', () {
    expect(PaywallSubscriptionCopy.periodLabel, contains('Aylık'));
    expect(PaywallSubscriptionCopy.termsBody, contains('otomatik yenilen'));
    expect(PaywallSubscriptionCopy.termsBody, contains('24 saat'));
  });

  testWidgets('terms show legal links; Apple EULA optional', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: PaywallSubscriptionTerms(
            onOpenUrl: (url) async => opened.add(url),
            showAppleEula: true,
          ),
        ),
      ),
    );

    expect(find.text(PaywallSubscriptionCopy.termsBody), findsOneWidget);
    expect(find.text('Kullanım koşulları'), findsOneWidget);
    expect(find.text('Gizlilik'), findsOneWidget);
    expect(find.text('Apple EULA'), findsOneWidget);

    await tester.tap(find.text('Kullanım koşulları'));
    await tester.tap(find.text('Gizlilik'));
    await tester.tap(find.text('Apple EULA'));
    await tester.pump();

    expect(opened, [
      LegalUrls.terms,
      LegalUrls.gizlilik,
      LegalUrls.appleStdEula,
    ]);
  });

  testWidgets('Android omits Apple EULA link', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: PaywallSubscriptionTerms(
            onOpenUrl: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Apple EULA'), findsNothing);
  });
}
