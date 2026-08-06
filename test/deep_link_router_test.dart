import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/navigation/deep_link_router.dart';

void main() {
  group('resolveDeepLink', () {
    test('null / empty → null', () {
      expect(resolveDeepLink(null), isNull);
      expect(resolveDeepLink(''), isNull);
      expect(resolveDeepLink('   '), isNull);
    });

    test('/dashboard?symbol=THYAO&horizon=7d → stock', () {
      final t = resolveDeepLink('/dashboard?symbol=THYAO&horizon=7d');
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'THYAO');
    });

    test('https dashboard symbol → stock', () {
      final t = resolveDeepLink(
        'https://lotlot.net/dashboard?symbol=GARAN&horizon=30d',
      );
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'GARAN');
    });

    test('sembol alias → stock', () {
      final t = resolveDeepLink('/x?sembol=aseis');
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'ASEIS');
    });

    test('lotlot://symbol/THYAO → stock', () {
      final t = resolveDeepLink('lotlot://symbol/THYAO');
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'THYAO');
    });

    test('lotlot://symbol/thyAO path case → upper', () {
      final t = resolveDeepLink('lotlot://symbol/thyAO');
      expect((t! as DeepLinkStock).symbol, 'THYAO');
    });

    test('lotlot path /symbol/THYAO → stock', () {
      final t = resolveDeepLink('lotlot:///symbol/THYAO');
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'THYAO');
    });

    test('lotlot://symbol/ alone → null', () {
      expect(resolveDeepLink('lotlot://symbol/'), isNull);
      expect(resolveDeepLink('lotlot://symbol'), isNull);
    });

    test('auth login + password_reset', () {
      final t = resolveDeepLink(
        'lotlot://auth/login?email=a%40b.com&password_reset=1',
      );
      expect(t, isA<DeepLinkAuthLogin>());
      final auth = t! as DeepLinkAuthLogin;
      expect(auth.email, 'a@b.com');
      expect(auth.passwordReset, isTrue);
    });

    test('auth login without password_reset', () {
      final t = resolveDeepLink('lotlot://auth/login?email=x@y.com');
      expect(t, isA<DeepLinkAuthLogin>());
      final auth = t! as DeepLinkAuthLogin;
      expect(auth.passwordReset, isFalse);
      expect(auth.email, 'x@y.com');
    });

    test('unknown path without symbol query → null', () {
      expect(resolveDeepLink('/dashboard'), isNull);
      expect(resolveDeepLink('https://lotlot.net/foo'), isNull);
    });

    test('lotlot:// never rewritten as https lotlot host garbage', () {
      // Pre-fix bug: non-http prefix made https://lotlot.net/lotlot://symbol/…
      final t = resolveDeepLink('lotlot://symbol/EREGL');
      expect(t, isA<DeepLinkStock>());
      expect((t! as DeepLinkStock).symbol, 'EREGL');
    });
  });
}
