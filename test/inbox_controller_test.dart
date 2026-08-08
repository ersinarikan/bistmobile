import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/features/notifications/inbox_controller.dart';

ApiClient _api(MockClientHandler handler) {
  FlutterSecureStorage.setMockInitialValues({
    'lotlot_access_token': 'test-access-token',
    'lotlot_refresh_token': 'test-refresh-token',
  });
  return ApiClient(
    tokenStorage: TokenStorage(storage: const FlutterSecureStorage()),
    httpClient: MockClient(handler),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InboxController', () {
    test('summary sets unreadCount', () async {
      final c = InboxController(
        apiClient: _api((request) async {
          expect(request.url.path, contains('/inbox/summary'));
          return http.Response(
            jsonEncode({'status': 'success', 'unread_count': 2}),
            200,
          );
        }),
      );
      await c.refreshSummary(force: true);
      expect(c.unreadCount, 2);
      c.dispose();
    });

    test('applyUnreadHint updates count immediately', () {
      final c = InboxController(
        apiClient: _api((request) async => http.Response('{}', 500)),
      );
      c.applyUnreadHint('4');
      expect(c.unreadCount, 4);
      c.applyUnreadHint(-1);
      expect(c.unreadCount, 4);
      c.dispose();
    });

    test('load parses items', () async {
      final c = InboxController(
        apiClient: _api((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/notifications/inbox'));
          expect(request.url.path, isNot(contains('summary')));
          return http.Response(
            jsonEncode({
              'status': 'success',
              'unread_count': 1,
              'items': [
                {
                  'id': 'uuid-1',
                  'created_at': '2026-08-07T00:00:00Z',
                  'read_at': null,
                  'type': 'signal_open',
                  'symbol': 'THYAO',
                  'title_tr': 'Baslik',
                  'body_tr': 'Govde',
                  'deep_link': '/dashboard?symbol=THYAO',
                },
              ],
              'next_cursor': null,
            }),
            200,
          );
        }),
      );
      await c.load();
      expect(c.items.length, 1);
      expect(c.items.first.symbol, 'THYAO');
      expect(c.items.first.isUnread, isTrue);
      expect(c.unreadCount, 1);
      c.dispose();
    });

    test('markRead updates unread from response', () async {
      final c = InboxController(
        apiClient: _api((request) async {
          if (request.method == 'POST' && request.url.path.contains('/read')) {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'id': 'uuid-1',
                'unread_count': 0,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'success',
              'unread_count': 1,
              'items': [
                {
                  'id': 'uuid-1',
                  'created_at': '2026-08-07T00:00:00Z',
                  'title_tr': 'X',
                },
              ],
            }),
            200,
          );
        }),
      );
      await c.load();
      await c.markRead('uuid-1');
      expect(c.unreadCount, 0);
      expect(c.items.first.isUnread, isFalse);
      c.dispose();
    });

    test('403 summary clears unread', () async {
      final c = InboxController(
        apiClient: _api((request) async {
          return http.Response(
            jsonEncode({
              'status': 'error',
              'error': 'premium_required',
              'message': 'Premium',
            }),
            403,
          );
        }),
      );
      await c.refreshSummary(force: true);
      expect(c.unreadCount, 0);
      c.dispose();
    });
  });
}
