import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/push/apns_token_wait.dart';

void main() {
  group('waitForApnsToken', () {
    test('returns first non-empty token', () async {
      var calls = 0;
      final token = await waitForApnsToken(
        readToken: () async {
          calls++;
          return calls >= 2 ? 'apns-token-abc' : null;
        },
        maxAttempts: 5,
        delay: Duration.zero,
      );
      expect(token, 'apns-token-abc');
      expect(calls, 2);
    });

    test('returns null when never ready', () async {
      var calls = 0;
      final token = await waitForApnsToken(
        readToken: () async {
          calls++;
          return null;
        },
        maxAttempts: 3,
        delay: Duration.zero,
      );
      expect(token, isNull);
      expect(calls, 3);
    });

    test('treats empty string as missing', () async {
      final token = await waitForApnsToken(
        readToken: () async => '',
        maxAttempts: 2,
        delay: Duration.zero,
      );
      expect(token, isNull);
    });

    test('maxAttempts < 1 → null without calling', () async {
      var calls = 0;
      final token = await waitForApnsToken(
        readToken: () async {
          calls++;
          return 'x';
        },
        maxAttempts: 0,
        delay: Duration.zero,
      );
      expect(token, isNull);
      expect(calls, 0);
    });
  });
}
