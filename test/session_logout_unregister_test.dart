import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';
import 'package:lotlotnet_mobile/features/auth/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout runs beforeLogout while tokens still present', () async {
    FlutterSecureStorage.setMockInitialValues({
      'lotlot_access_token': 'access-token',
      'lotlot_refresh_token': 'refresh-token',
    });
    final storage = TokenStorage(storage: const FlutterSecureStorage());
    final calls = <String>[];
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        return http.Response('{"status":"success"}', 200);
      }),
    );
    final session = SessionController(tokenStorage: storage, apiClient: api);
    var beforeSawAccess = false;
    session.beforeLogout = () async {
      beforeSawAccess = (await storage.readAccessToken()) != null;
      calls.add('beforeLogout');
    };

    await session.logout();

    expect(beforeSawAccess, isTrue);
    expect(calls.first, 'beforeLogout');
    expect(calls, contains('/api/auth/logout'));
    expect(await storage.readAccessToken(), isNull);
    expect(session.status, AuthStatus.unauthenticated);
  });
}
