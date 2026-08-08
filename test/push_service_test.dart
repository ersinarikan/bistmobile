import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/push/push_service.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';

ApiClient _apiClient({MockClientHandler? handler}) {
  FlutterSecureStorage.setMockInitialValues({
    'lotlot_access_token': 'test-access-token',
    'lotlot_refresh_token': 'test-refresh-token',
  });
  return ApiClient(
    tokenStorage: TokenStorage(storage: const FlutterSecureStorage()),
    httpClient: MockClient(
      handler ??
          (request) async => http.Response('{"success":true}', 200),
    ),
  );
}

PushService _push({
  MockClientHandler? handler,
  Future<String?> Function()? readApnsToken,
  Future<String?> Function()? readFcmToken,
  Future<bool> Function()? ensurePermissionOverride,
  bool isIos = true,
}) {
  return PushService(
    apiClient: _apiClient(handler: handler),
    readApnsToken: readApnsToken,
    readFcmToken: readFcmToken,
    ensurePermissionOverride: ensurePermissionOverride,
    isIos: isIos,
    apnsRetryDelay: Duration.zero,
    apnsMaxAttempts: 3,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushService.fetchToken', () {
    test('returns null when firebase not ready', () async {
      final push = _push(
        readApnsToken: () async => 'apns',
        readFcmToken: () async => 'fcm-token-long-enough-12345',
      );
      expect(await push.fetchToken(), isNull);
    });

    test('iOS: APNs missing → null + apns_token_unavailable', () async {
      final push = _push(
        readApnsToken: () async => null,
        readFcmToken: () async => 'should-not-be-called',
      )..firebaseReady = true;

      expect(await push.fetchToken(), isNull);
      expect(push.lastError, 'apns_token_unavailable');
    });

    test('iOS: APNs then FCM token', () async {
      var apnsCalls = 0;
      final push = _push(
        readApnsToken: () async {
          apnsCalls++;
          return apnsCalls >= 2 ? 'apns-ok' : null;
        },
        readFcmToken: () async => 'fcm-token-long-enough-12345',
      )..firebaseReady = true;

      expect(await push.fetchToken(), 'fcm-token-long-enough-12345');
      expect(push.lastToken, 'fcm-token-long-enough-12345');
      expect(apnsCalls, 2);
    });

    test('non-iOS skips APNs wait', () async {
      var apnsCalls = 0;
      final push = _push(
        isIos: false,
        readApnsToken: () async {
          apnsCalls++;
          return null;
        },
        readFcmToken: () async => 'android-fcm-token-1234567890',
      )..firebaseReady = true;

      expect(await push.fetchToken(), 'android-fcm-token-1234567890');
      expect(apnsCalls, 0);
    });
  });

  group('PushService.syncRegistration', () {
    test('premium off → false without register', () async {
      var registered = false;
      final push = _push(
        handler: (request) async {
          if (request.url.path.contains('device/register')) {
            registered = true;
          }
          return http.Response('{"success":true}', 200);
        },
        ensurePermissionOverride: () async => true,
      )..firebaseReady = true;

      final ok = await push.syncRegistration(isPremium: false, pushOn: true);
      expect(ok, isFalse);
      expect(registered, isFalse);
    });

    test('firebase missing → status message (iOS hint)', () async {
      final push = _push(ensurePermissionOverride: () async => true)
        ..firebaseReady = false;
      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isFalse);
      expect(push.statusMessage, contains('Firebase'));
      expect(push.statusMessage, contains('GoogleService-Info.plist'));
    });

    test('firebase missing → status message (Android hint)', () async {
      final push = _push(
        ensurePermissionOverride: () async => true,
        isIos: false,
      )..firebaseReady = false;
      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isFalse);
      expect(push.statusMessage, contains('Firebase'));
      expect(push.statusMessage, contains('google-services.json'));
    });

    test('short FCM token → Android status omits APNs', () async {
      final push = _push(
        isIos: false,
        readFcmToken: () async => 'short',
        ensurePermissionOverride: () async => true,
      )..firebaseReady = true;

      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isFalse);
      expect(push.statusMessage, contains('FCM token'));
      expect(push.statusMessage, isNot(contains('APNs')));
    });

    test('short FCM token → status message', () async {
      final push = _push(
        readApnsToken: () async => 'apns',
        readFcmToken: () async => 'short',
        ensurePermissionOverride: () async => true,
      )..firebaseReady = true;

      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isFalse);
      expect(push.statusMessage, contains('FCM token'));
    });

    test('happy path registers ios device', () async {
      String? platform;
      String? token;
      final push = _push(
        readApnsToken: () async => 'apns',
        readFcmToken: () async => 'fcm-token-long-enough-12345',
        ensurePermissionOverride: () async => true,
        handler: (request) async {
          if (request.url.path.contains('device/register')) {
            platform = request.url.path; // set below from body
            token = request.body;
            return http.Response('{"success":true}', 200);
          }
          if (request.url.path.contains('device/unregister')) {
            return http.Response('{"success":true,"deleted":0}', 200);
          }
          return http.Response('{"success":true}', 200);
        },
      )..firebaseReady = true;

      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isTrue);
      expect(push.statusMessage, contains('tamam'));
      expect(token, contains('fcm-token-long-enough-12345'));
      expect(token, contains('"platform":"ios"'));
      expect(platform, isNotNull);
    });

    test('permission denied → status', () async {
      final push = _push(
        ensurePermissionOverride: () async => false,
      )..firebaseReady = true;

      final ok = await push.syncRegistration(isPremium: true, pushOn: true);
      expect(ok, isFalse);
      expect(push.statusMessage, contains('Bildirim izni'));
    });
  });

  group('PushService.unregisterQuiet', () {
    test('clearAll posts unregister without token body', () async {
      String? body;
      final push = _push(
        handler: (request) async {
          if (request.url.path.contains('device/unregister')) {
            body = request.body;
            return http.Response('{"success":true,"deleted":1}', 200);
          }
          return http.Response('{"success":true}', 200);
        },
      )..lastToken = 'fcm-token-long-enough-12345';

      await push.unregisterQuiet(clearAll: true);
      expect(body, isNotNull);
      expect(body, isNot(contains('fcm-token-long-enough-12345')));
      expect(push.lastToken, 'fcm-token-long-enough-12345');
    });

    test('token-specific unregister when clearAll false', () async {
      String? body;
      final push = _push(
        handler: (request) async {
          if (request.url.path.contains('device/unregister')) {
            body = request.body;
            return http.Response('{"success":true,"deleted":1}', 200);
          }
          return http.Response('{"success":true}', 200);
        },
      )..lastToken = 'fcm-token-long-enough-12345';

      await push.unregisterQuiet(clearAll: false);
      expect(body, contains('fcm-token-long-enough-12345'));
    });

    test('API error is swallowed', () async {
      final push = _push(
        handler: (request) async => http.Response('{"error":"x"}', 500),
      )..lastToken = 'fcm-token-long-enough-12345';

      await push.unregisterQuiet(clearAll: true);
    });
  });

  group('parsePushUnreadCount', () {
    test('parses num and string', () {
      expect(parsePushUnreadCount(3), 3);
      expect(parsePushUnreadCount('7'), 7);
      expect(parsePushUnreadCount(0), 0);
    });

    test('rejects invalid / negative', () {
      expect(parsePushUnreadCount(null), isNull);
      expect(parsePushUnreadCount(-1), isNull);
      expect(parsePushUnreadCount('x'), isNull);
      expect(parsePushUnreadCount(''), isNull);
    });
  });

  group('PushService.attachMessagingHandlers', () {
    test('no-op when firebase not ready', () {
      final push = _push();
      push.attachMessagingHandlers(onMessageData: (_) {});
      // Does not throw; stream not attached without Firebase.
    });
  });
}
