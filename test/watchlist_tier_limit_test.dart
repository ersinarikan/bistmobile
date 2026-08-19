import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/core/theme/app_theme.dart';
import 'package:lotlotnet_mobile/features/auth/session_controller.dart';
import 'package:lotlotnet_mobile/features/chart_alerts/chart_alert_row.dart';
import 'package:lotlotnet_mobile/features/chart_alerts/chart_alerts_controller.dart';
import 'package:lotlotnet_mobile/features/watchlist/watchlist_controller.dart';
import 'package:lotlotnet_mobile/features/watchlist/watchlist_screen.dart';
import 'package:lotlotnet_mobile/features/watchlist/widgets/watchlist_signal_tile.dart';
import 'package:lotlotnet_mobile/features/watchlist/widgets/watchlist_tier_hold_banner.dart';
import 'package:provider/provider.dart';

ApiClient _api(MockClientHandler handler) {
  FlutterSecureStorage.setMockInitialValues({
    'lotlot_access_token': 'access',
    'lotlot_refresh_token': 'refresh',
  });
  return ApiClient(
    tokenStorage: TokenStorage(storage: const FlutterSecureStorage()),
    httpClient: MockClient(handler),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabledReasonLabel maps tier_limit', () {
    expect(
      disabledReasonLabel('tier_limit'),
      'Plan limitinde bekliyor — analiz ve detay kapalı',
    );
    expect(disabledReasonLabel('other'), 'other');
    expect(disabledReasonLabel(null), contains('pasif'));
    expect(disabledReasonLabel(''), contains('pasif'));
  });

  test('mutationsCarryoverExhausted only when used exceeds cap', () async {
    final wl = WatchlistController(
      apiClient: _api((request) async {
        if (request.url.path.endsWith('/predictions')) {
          return http.Response(jsonEncode({'status': 'success', 'items': []}), 200);
        }
        if (request.url.path.contains('pattern-analysis')) {
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'watchlist': [
              {'symbol': 'THYAO', 'active': true},
            ],
            'subscription': {
              'watchlist_active_count': 1,
              'watchlist_inactive_count': 0,
              'watchlist_limit': 10,
              'monthly_watchlist_mutations_used': 10,
              'monthly_watchlist_mutations_remaining': 0,
            },
          }),
          200,
        );
      }),
    );
    await wl.refresh();
    expect(wl.mutationsCarryoverExhausted, isFalse);
    expect(wl.mutationsUsed, 10);
    expect(wl.mutationsRemaining, 0);
  });

  test('refresh sorts active first and uses subscription kota', () async {
    final wl = WatchlistController(
      apiClient: _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/predictions')) {
          return http.Response(jsonEncode({'status': 'success', 'items': []}), 200);
        }
        if (path.contains('pattern-analysis')) {
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'watchlist': [
              {
                'symbol': 'ASELS',
                'name': 'Aselsan',
                'active': false,
                'disabled_reason': 'tier_limit',
              },
              {'symbol': 'THYAO', 'name': 'THY', 'active': true},
              {
                'symbol': 'GARAN',
                'active': false,
                'disabled_reason': 'tier_limit',
              },
            ],
            'subscription': {
              'watchlist_active_count': 10,
              'watchlist_inactive_count': 8,
              'watchlist_limit': 10,
              'monthly_watchlist_mutations_used': 36,
              'monthly_watchlist_mutations_remaining': 0,
            },
          }),
          200,
        );
      }),
    );
    await wl.refresh();
    expect(wl.items.first['symbol'], 'THYAO');
    expect(WatchlistController.isItemActive(wl.items[1]), isFalse);
    expect(wl.activeCount, 10);
    expect(wl.inactiveCount, 8);
    expect(wl.mutationsCarryoverExhausted, isTrue);
    // Pasifler için pattern hydrate edilmez — map boş kalabilir / sadece aktif.
    expect(wl.patternForSymbol('ASELS'), isNull);
  });

  test('ChartAlertsController kota uses active status only', () {
    final c = ChartAlertsController(
      apiClient: _api((_) async => http.Response('{}', 500)),
    );
    c.alerts = [
      {'id': '1', 'symbol': 'A', 'status': 'active'},
      {'id': '2', 'symbol': 'B', 'status': 'paused'},
      {'id': '3', 'symbol': 'C', 'status': 'active'},
      {'id': '4', 'symbol': 'D', 'active': false},
    ];
    c.limits = {'limit': 20};
    expect(c.activeAlerts.length, 2);
    expect(c.pausedAlerts.length, 2);
    expect(c.used, 2);
    expect(c.limit, 20);
    expect(ChartAlertsController.isAlertActive(c.alerts[1]), isFalse);
    expect(ChartAlertsController.isAlertActive(c.alerts[3]), isFalse);
  });

  testWidgets('inactive tile shows plan limit, no Detay', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = _api((_) async => http.Response('{}', 500));
    final tokens = TokenStorage(storage: const FlutterSecureStorage());
    final wl = WatchlistController(apiClient: api);
    final session = SessionController(tokenStorage: tokens, apiClient: api);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wl),
            ChangeNotifierProvider.value(value: session),
          ],
          child: Scaffold(
            body: WatchlistSignalTile(
              item: {
                'symbol': 'ALTNY',
                'name': 'Altınay',
                'active': false,
                'disabled_reason': 'tier_limit',
                'alert_enabled': true,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('ALTNY'), findsOneWidget);
    expect(
      find.text('Plan limitinde bekliyor — analiz ve detay kapalı'),
      findsOneWidget,
    );
    expect(find.text('Plan yükselt'), findsOneWidget);
    expect(find.text('Detay'), findsNothing);
    expect(find.text('tier_limit'), findsNothing);
    expect(find.textContaining('Bildirim'), findsNothing);
  });

  testWidgets('tier-hold banner uses web v654 copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: WatchlistTierHoldBanner()),
      ),
    );
    expect(find.text(WatchlistTierHoldBanner.copy), findsOneWidget);
  });

  testWidgets('paused chart alert row shows plan-limit label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ChartAlertRow(
            alert: {
              'id': '2',
              'symbol': 'THYAO',
              'status': 'paused',
              'summary_tr': 'Fiyat > 100',
            },
          ),
        ),
      ),
    );
    expect(find.text('THYAO'), findsOneWidget);
    expect(find.text(ChartAlertRow.pausedLabel), findsOneWidget);
    expect(find.text('Fiyat > 100'), findsOneWidget);
  });

  testWidgets('watchlist screen shows kota, banner and hold row', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'lotlot_access_token': 'access',
      'lotlot_refresh_token': 'refresh',
    });
    final api = _api((request) async {
      final path = request.url.path;
      if (path.endsWith('/predictions')) {
        return http.Response(jsonEncode({'status': 'success', 'items': []}), 200);
      }
      if (path.contains('pattern-analysis')) {
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }
      return http.Response(
        jsonEncode({
          'status': 'success',
          'watchlist': [
            {'symbol': 'THYAO', 'name': 'THY', 'active': true},
            {
              'symbol': 'ASELS',
              'name': 'Aselsan',
              'active': false,
              'disabled_reason': 'tier_limit',
            },
          ],
          'subscription': {
            'watchlist_active_count': 10,
            'watchlist_inactive_count': 8,
            'watchlist_limit': 10,
            'monthly_watchlist_mutations_used': 36,
            'monthly_watchlist_mutations_remaining': 0,
          },
        }),
        200,
      );
    });
    final tokens = TokenStorage(storage: const FlutterSecureStorage());
    final session = SessionController(tokenStorage: tokens, apiClient: api)
      ..status = AuthStatus.authenticated;
    final wl = WatchlistController(apiClient: api);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wl),
            ChangeNotifierProvider.value(value: session),
          ],
          child: const Scaffold(body: WatchlistScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 / 10 hisse'), findsOneWidget);
    expect(find.text('8 hisse plan limitinde bekliyor'), findsOneWidget);
    expect(
      find.text(
        'Üst sınır aşıldı; yeni hak yok. Fazla kullanım önceki plandan kalma.',
      ),
      findsOneWidget,
    );
    expect(find.text(WatchlistTierHoldBanner.copy), findsOneWidget);
    expect(find.text('THYAO'), findsOneWidget);
    expect(find.text('ASELS'), findsOneWidget);
    expect(find.text('Detay'), findsOneWidget);
  });
}
