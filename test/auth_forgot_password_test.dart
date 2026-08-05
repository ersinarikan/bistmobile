import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/api/api_client.dart';
import 'package:lotlotnet_mobile/features/auth/auth_helpers.dart';
import 'package:lotlotnet_mobile/features/auth/session_controller.dart';

void main() {
  group('isPasswordResetQuery', () {
    test('accepts 1 true yes', () {
      expect(isPasswordResetQuery({'password_reset': '1'}), isTrue);
      expect(isPasswordResetQuery({'password_reset': 'true'}), isTrue);
      expect(isPasswordResetQuery({'password_reset': 'YES'}), isTrue);
    });

    test('rejects empty or other', () {
      expect(isPasswordResetQuery({}), isFalse);
      expect(isPasswordResetQuery({'password_reset': '0'}), isFalse);
    });
  });

  group('AuthCopy', () {
    test('messages non-empty', () {
      expect(AuthCopy.passwordResetSent, contains('bağlantısı'));
      expect(AuthCopy.passwordResetDone, contains('giriş'));
    });
  });

  group('isAllowedTurnstileNavigation', () {
    test('allows lotlot and cloudflare', () {
      expect(
        isAllowedTurnstileNavigation('https://lotlot.net/mobile/turnstile'),
        isTrue,
      );
      expect(
        isAllowedTurnstileNavigation(
          'https://challenges.cloudflare.com/cdn-cgi/challenge',
        ),
        isTrue,
      );
      expect(isAllowedTurnstileNavigation('about:blank'), isTrue);
    });

    test('blocks strangers', () {
      expect(
        isAllowedTurnstileNavigation('https://evil.example/phish'),
        isFalse,
      );
      expect(isAllowedTurnstileNavigation('javascript:alert(1)'), isFalse);
    });
  });

  group('mapForgotPasswordException', () {
    test('captcha and turnstile', () {
      expect(
        mapForgotPasswordException(
          ApiException(
            statusCode: 400,
            message: 'x',
            errorCode: 'captcha_required',
            body: {'captcha_required': true},
          ),
        ),
        PasswordResetResult.needsTurnstile,
      );
      expect(
        mapForgotPasswordException(
          ApiException(
            statusCode: 400,
            message: 'bad turnstile',
            errorCode: 'invalid_turnstile',
          ),
        ),
        PasswordResetResult.needsTurnstile,
      );
    });

    test('other errors failed', () {
      expect(
        mapForgotPasswordException(
          ApiException(
            statusCode: 400,
            message: 'bad',
            errorCode: 'invalid_email',
          ),
        ),
        PasswordResetResult.failed,
      );
      expect(
        mapForgotPasswordException(
          ApiException(
            statusCode: 429,
            message: 'wait',
            errorCode: 'rate_limited',
          ),
        ),
        PasswordResetResult.failed,
      );
    });
  });
}
