import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/features/auth/auth_helpers.dart';
import 'package:lotlotnet_mobile/features/auth/session_controller.dart';

Map<String, dynamic> _authOk({required String email}) => {
      'status': 'success',
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'user': {
        'id': 42,
        'email': email,
        'full_name': 'Test User',
        'provider': 'google',
        'email_verified': true,
      },
      'subscription': {
        'tier': 'premium',
        'trial_active': true,
        'is_pro': true,
        'is_premium': true,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(storage: const FlutterSecureStorage());
  });

  test('Google signup without turnstile returns needsTurnstile', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'error': 'signup_turnstile_required',
            'message': 'Yeni hesap için güvenlik doğrulaması gerekli.',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken('id-token');

    expect(result, LoginResult.needsTurnstile);
    expect(session.lastErrorCode, 'signup_turnstile_required');
    expect(bodies.single['idToken'], 'id-token');
    expect(bodies.single.containsKey('turnstile_token'), isFalse);
  });

  test('Google signup with turnstile succeeds', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(_authOk(email: 'new@gmail.com')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken(
      'id-token',
      turnstileToken: 'ok-turnstile',
    );

    expect(result, LoginResult.success);
    expect(session.status, AuthStatus.authenticated);
    expect(session.user?['email'], 'new@gmail.com');
    expect(bodies.single['idToken'], 'id-token');
    expect(bodies.single['turnstile_token'], 'ok-turnstile');
    expect(await storage.readAccessToken(), 'access-token');
  });

  test('Google login existing account skips turnstile', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(_authOk(email: 'existing@gmail.com')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken('id-token');

    expect(result, LoginResult.success);
    expect(bodies.single.containsKey('turnstile_token'), isFalse);
    expect(session.user?['email'], 'existing@gmail.com');
  });

  test('invalid_turnstile returns needsTurnstile', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_turnstile',
            'message': 'Güvenlik doğrulaması başarısız.',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken(
      'id-token',
      turnstileToken: 'bad',
    );

    expect(result, LoginResult.needsTurnstile);
    expect(session.lastErrorCode, 'invalid_turnstile');
  });

  test('lazy: obtains turnstile after signup_turnstile_required', () async {
    var calls = 0;
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (!body.containsKey('turnstile_token')) {
          return http.Response(
            jsonEncode({'error': 'signup_turnstile_required'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(_authOk(email: 'lazy@gmail.com')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdTokenLazy(
      'id-token',
      obtainTurnstile: () async => 'bridge-token',
    );

    expect(result, LoginResult.success);
    expect(calls, 2);
    expect(session.user?['email'], 'lazy@gmail.com');
  });

  test('lazy: cancel turnstile → failed', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'signup_turnstile_required'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdTokenLazy(
      'id-token',
      obtainTurnstile: () async => null,
    );

    expect(result, LoginResult.failed);
    expect(session.lastError, AuthCopy.turnstileRequired);
  });

  test('lazy: invalid turnstile after bridge → failed', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (!body.containsKey('turnstile_token')) {
          return http.Response(
            jsonEncode({'error': 'signup_turnstile_required'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'error': 'invalid_turnstile'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdTokenLazy(
      'id-token',
      obtainTurnstile: () async => 'stale',
    );

    expect(result, LoginResult.failed);
    expect(session.lastError, AuthCopy.turnstileRetry);
  });

  test('400 turnstile message without error code → needsTurnstile', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Please complete turnstile challenge'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken('id-token');

    expect(result, LoginResult.needsTurnstile);
  });

  test('unexpected exception during Google login → failed', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        throw StateError('network down');
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);

    final result = await session.loginWithGoogleIdToken('id-token');

    expect(result, LoginResult.failed);
    expect(session.lastErrorCode, isNull);
    expect(session.lastError, contains('network down'));
  });
}
