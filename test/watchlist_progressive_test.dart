import 'dart:async';
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

  test('P1 refresh paints items before slow predictions', () async {
    final predGate = Completer<void>();
    final c = WatchlistController(
      apiClient: _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/predictions')) {
          await predGate.future;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'items': [
                {
                  'symbol': 'THYAO',
                  'current_price': 100,
                  'signals_by_horizon': {
                    '7d': {'label': 'AL', 'genel_confidence_pct': 70},
                  },
                },
              ],
            }),
            200,
          );
        }
        if (path.contains('pattern-analysis')) {
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'watchlist': [
              {'symbol': 'THYAO', 'name': 'THY', 'active': true},
            ],
            'subscription': {
              'watchlist_active_count': 1,
              'watchlist_limit': 100,
            },
          }),
          200,
        );
      }),
    );

    final done = c.refresh();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.items.length, 1);
    expect(c.loading, isFalse);
    expect(c.enrichingPredictions, isTrue);
    expect(c.predictionForSymbol('THYAO'), isNull);

    predGate.complete();
    await done;
    expect(c.enriching, isFalse);
    expect(c.predictionForSymbol('THYAO')?['current_price'], 100);
    c.dispose();
  });

  test('P2 predictions HTML 429 keeps list', () async {
    final c = WatchlistController(
      apiClient: _api((request) async {
        if (request.url.path.endsWith('/predictions')) {
          return http.Response(
            '<html><title>429 Too Many Requests</title></html>',
            429,
          );
        }
        if (request.url.path.contains('pattern-analysis')) {
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
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
      }),
    );

    await c.refresh();
    expect(c.items.length, 1);
    expect(c.lastError, contains('hızlı'));
    expect(c.enriching, isFalse);
    c.dispose();
  });

  test('P3 pattern chunk failure keeps predictions', () async {
    final c = WatchlistController(
      apiClient: _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/predictions')) {
          return http.Response(
            jsonEncode({
              'items': [
                {'symbol': 'THYAO', 'current_price': 12},
              ],
            }),
            200,
          );
        }
        if (path.contains('pattern-analysis')) {
          return http.Response('nope', 500);
        }
        return http.Response(
          jsonEncode({
            'watchlist': [
              {'symbol': 'THYAO', 'active': true},
            ],
            'subscription': {'watchlist_active_count': 1, 'watchlist_limit': 10},
          }),
          200,
        );
      }),
    );

    await c.refresh();
    expect(c.items.length, 1);
    expect(c.predictionForSymbol('THYAO')?['current_price'], 12);
    expect(c.patternForSymbol('THYAO'), isNull);
    c.dispose();
  });

  test('P4 second refresh drops stale enrich', () async {
    var watchlistCalls = 0;
    final slowPred = Completer<void>();
    final c = WatchlistController(
      apiClient: _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/watchlist') && !path.contains('predictions')) {
          watchlistCalls++;
          final symbol = watchlistCalls == 1 ? 'AAAA' : 'BBBB';
          return http.Response(
            jsonEncode({
              'watchlist': [
                {'symbol': symbol, 'active': true},
              ],
              'subscription': {
                'watchlist_active_count': 1,
                'watchlist_limit': 100,
              },
            }),
            200,
          );
        }
        if (path.endsWith('/predictions')) {
          if (watchlistCalls == 1) {
            await slowPred.future;
            return http.Response(
              jsonEncode({
                'items': [
                  {'symbol': 'AAAA', 'current_price': 1},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'items': [
                {'symbol': 'BBBB', 'current_price': 2},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }),
    );

    final first = c.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.items.single['symbol'], 'AAAA');

    final second = c.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.items.single['symbol'], 'BBBB');

    slowPred.complete();
    await first;
    await second;

    expect(c.items.single['symbol'], 'BBBB');
    expect(c.predictionForSymbol('AAAA'), isNull);
    expect(c.predictionForSymbol('BBBB')?['current_price'], 2);
    c.dispose();
  });

  test('P5 removeSymbol clears mutating before enrich finishes', () async {
    final predGate = Completer<void>();
    final c = WatchlistController(
      apiClient: _api((request) async {
        if (request.method == 'DELETE') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'subscription': {
                'watchlist_active_count': 0,
                'watchlist_limit': 100,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/predictions')) {
          await predGate.future;
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (request.url.path.contains('pattern-analysis')) {
          return http.Response(jsonEncode({}), 200);
        }
        return http.Response(
          jsonEncode({
            'watchlist': <dynamic>[],
            'subscription': {
              'watchlist_active_count': 0,
              'watchlist_limit': 100,
            },
          }),
          200,
        );
      }),
    );
    c.items = [
      {'symbol': 'THYAO', 'active': true},
    ];

    final fut = c.removeSymbol('THYAO');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.items, isEmpty);
    expect(c.mutating, isFalse);
    expect(c.enrichingPredictions || c.loading || c.enriching, isTrue);

    predGate.complete();
    expect(await fut, isTrue);
    expect(c.enriching, isFalse);
    c.dispose();
  });
}
