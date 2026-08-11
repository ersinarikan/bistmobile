import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'lotlot_access_token': 'access',
      'lotlot_refresh_token': 'refresh',
    });
    storage = TokenStorage(storage: const FlutterSecureStorage());
  });

  test('nginx HTML 429 becomes rate_limited ApiException', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          '<html>\r\n<head><title>429 Too Many Requests</title></head>\r\n'
          '<body>\r\n<center><h1>429 Too Many Requests</h1></center>\r\n'
          '<hr><center>nginx</center>\r\n</body>\r\n</html>\r\n',
          429,
          headers: {'content-type': 'text/html'},
        );
      }),
    );

    try {
      await api.fetchWatchlist();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 429);
      expect(e.errorCode, 'rate_limited');
      expect(e.message, contains('hızlı'));
    }
  });

  test('HTML 502 becomes invalid_response without FormatException', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          '<html><body>Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      }),
    );

    try {
      await api.removeWatchlist('THYAO');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 502);
      expect(e.errorCode, 'invalid_response');
    }
  });

  test('empty-body 429 uses rate_limited fallback message', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async => http.Response('', 429)),
    );
    try {
      await api.fetchWatchlist();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 429);
      expect(e.errorCode, 'rate_limited');
      expect(e.message, contains('hızlı'));
    }
  });

  test('JSON 429 keeps API message and rate_limited code', () async {
    final api = ApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'rate_limited',
            'message': 'Rate limited, please wait.',
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    try {
      await api.fetchWatchlist();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 429);
      expect(e.errorCode, 'rate_limited');
      expect(e.message, 'Rate limited, please wait.');
    }
  });
}
