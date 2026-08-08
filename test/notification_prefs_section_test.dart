import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/features/account/notification_pref_display.dart';
import 'package:lotlotnet_mobile/features/account/notification_prefs_section.dart';
import 'package:lotlotnet_mobile/features/pro/soft_gate_sheet.dart';

void main() {
  group('notificationPrefsLayout', () {
    test('free', () {
      expect(
        notificationPrefsLayout(isPro: false, isPremium: false),
        NotificationPrefsLayout.freeCta,
      );
    });
    test('pro', () {
      expect(
        notificationPrefsLayout(isPro: true, isPremium: false),
        NotificationPrefsLayout.proEmailPushLocked,
      );
    });
    test('premium', () {
      expect(
        notificationPrefsLayout(isPro: true, isPremium: true),
        NotificationPrefsLayout.premiumBoth,
      );
    });
  });

  group('effective prefs', () {
    test('email clamped', () {
      expect(
        effectiveEmailNotificationsOn(isPro: false, rawEmailOn: true),
        isFalse,
      );
      expect(
        effectiveEmailNotificationsOn(isPro: true, rawEmailOn: true),
        isTrue,
      );
    });
    test('push clamped', () {
      expect(
        effectivePushNotificationsOn(isPremium: false, rawPushOn: true),
        isFalse,
      );
      expect(
        effectivePushNotificationsOn(isPremium: true, rawPushOn: true),
        isTrue,
      );
    });
  });

  test('gate kinds', () {
    expect(emailEnableGateKind(), SoftGateKind.pro);
    expect(pushEnableGateKind(), SoftGateKind.premium);
  });

  testWidgets('free layout shows plan CTA without switches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationPrefsSection(
            layout: NotificationPrefsLayout.freeCta,
            emailOn: false,
            pushOn: false,
            unread: 0,
            prefsReady: true,
            patchingEmail: false,
            patchingPush: false,
            onEmailChanged: (_) {},
            onPushChanged: (_) {},
            onOpenPlans: () {},
            onPremiumGate: () {},
            onOpenInbox: () {},
          ),
        ),
      ),
    );
    expect(find.text('Planları incele'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Gelen bildirimler'), findsOneWidget);
  });

  testWidgets('pro layout email switch + locked push', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationPrefsSection(
            layout: NotificationPrefsLayout.proEmailPushLocked,
            emailOn: true,
            pushOn: false,
            unread: 2,
            prefsReady: true,
            patchingEmail: false,
            patchingPush: false,
            onEmailChanged: (_) {},
            onPushChanged: (_) {},
            onOpenPlans: () {},
            onPremiumGate: () {},
            onOpenInbox: () {},
          ),
        ),
      ),
    );
    expect(find.text('E-posta bildirimleri'), findsOneWidget);
    expect(find.text('Push / anlık bildirimler'), findsOneWidget);
    expect(find.text('Push bildirimleri'), findsNothing);
    expect(find.text('2 okunmamış · Push geçmişi'), findsOneWidget);
  });

  testWidgets('premium layout both switches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationPrefsSection(
            layout: NotificationPrefsLayout.premiumBoth,
            emailOn: true,
            pushOn: true,
            unread: 0,
            prefsReady: true,
            patchingEmail: false,
            patchingPush: false,
            onEmailChanged: (_) {},
            onPushChanged: (_) {},
            onOpenPlans: () {},
            onPremiumGate: () {},
            onOpenInbox: () {},
          ),
        ),
      ),
    );
    expect(find.text('E-posta bildirimleri'), findsOneWidget);
    expect(find.text('Push bildirimleri'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });
}
