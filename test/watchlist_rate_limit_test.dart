import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/features/watchlist/watchlist_controller.dart';

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

  test('refresh keeps items when GET watchlist returns HTML 429', () async {
    var n = 0;
    final c = WatchlistController(
      apiClient: _api((request) async {
        n++;
        if (n == 1) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'watchlist': [
                {'symbol': 'THYAO', 'active': true},
                {'symbol': 'GARAN', 'active': true},
              ],
              'subscription': {
                'watchlist_active_count': 2,
                'watchlist_limit': 100,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/predictions')) {
          return http.Response(jsonEncode({'status': 'success', 'items': []}), 200);
        }
        if (request.url.path.contains('pattern')) {
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
        // second refresh: nginx HTML rate limit
        return http.Response(
          '<html><head><title>429 Too Many Requests</title></head></html>',
          429,
        );
      }),
    );

    await c.refresh();
    expect(c.items.length, 2);

    await c.refresh();
    expect(c.items.length, 2);
    expect(c.lastError, contains('hızlı'));
    c.dispose();
  });

  test('removeSymbol succeeds locally even if refresh predictions 429', () async {
    final c = WatchlistController(
      apiClient: _api((request) async {
        if (request.method == 'DELETE') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'message': 'THYAO removed',
              'subscription': {
                'watchlist_active_count': 1,
                'watchlist_limit': 100,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/api/watchlist')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'watchlist': [
                {'symbol': 'GARAN', 'active': true},
              ],
              'subscription': {
                'watchlist_active_count': 1,
                'watchlist_limit': 100,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/predictions')) {
          return http.Response(
            '<html><title>429 Too Many Requests</title></html>',
            429,
          );
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }),
    );

    c.items = [
      {'symbol': 'THYAO', 'active': true},
      {'symbol': 'GARAN', 'active': true},
    ];
    c.subscription = {
      'watchlist_active_count': 2,
      'watchlist_limit': 100,
    };

    final ok = await c.removeSymbol('THYAO');
    expect(ok, isTrue);
    expect(c.items.map((e) => e['symbol']), ['GARAN']);
    expect(c.lastError, contains('hızlı'));
    c.dispose();
  });

  test('refresh clears items on 403 but keeps them on 502', () async {
    var watchlistCalls = 0;
    final c = WatchlistController(
      apiClient: _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/predictions') || path.contains('pattern')) {
          return http.Response(jsonEncode({'status': 'success', 'items': []}), 200);
        }
        if (path.endsWith('/api/watchlist')) {
          watchlistCalls++;
          if (watchlistCalls == 1) {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'watchlist': [
                  {'symbol': 'THYAO', 'active': true},
                ],
                'subscription': {
                  'watchlist_active_count': 1,
                  'watchlist_limit': 100,
                },
              }),
              200,
            );
          }
          if (watchlistCalls == 2) {
            return http.Response(
              jsonEncode({'error': 'forbidden', 'message': 'nope'}),
              403,
            );
          }
          return http.Response('<html>Bad Gateway</html>', 502);
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }),
    );

    await c.refresh();
    expect(c.items.length, 1);

    await c.refresh();
    expect(c.items, isEmpty);

    c.items = [
      {'symbol': 'GARAN', 'active': true},
    ];
    await c.refresh();
    expect(c.items.length, 1);
    expect(c.lastError, isNotNull);
    c.dispose();
  });

  test('removeSymbol ApiException surfaces friendly rate limit', () async {
    final c = WatchlistController(
      apiClient: _api((request) async {
        return http.Response(
          '<html><title>429 Too Many Requests</title></html>',
          429,
        );
      }),
    );
    c.items = [
      {'symbol': 'THYAO', 'active': true},
    ];
    final ok = await c.removeSymbol('THYAO');
    expect(ok, isFalse);
    expect(c.items.length, 1);
    expect(c.lastError, contains('hızlı'));
    c.dispose();
  });

  test('removeSymbol ignores concurrent call while mutating', () async {
    var deletes = 0;
    final started = <Future<bool>>[];
    final c = WatchlistController(
      apiClient: _api((request) async {
        if (request.method == 'DELETE') {
          deletes++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return http.Response(
            jsonEncode({
              'status': 'success',
              'subscription': {'watchlist_active_count': 0, 'watchlist_limit': 100},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/predictions')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'watchlist': <dynamic>[],
            'subscription': {'watchlist_active_count': 0, 'watchlist_limit': 100},
          }),
          200,
        );
      }),
    );
    c.items = [
      {'symbol': 'THYAO', 'active': true},
    ];

    started.add(c.removeSymbol('THYAO'));
    started.add(c.removeSymbol('THYAO'));
    final results = await Future.wait(started);
    expect(deletes, 1);
    expect(results.where((e) => e).length, 1);
    c.dispose();
  });
}
