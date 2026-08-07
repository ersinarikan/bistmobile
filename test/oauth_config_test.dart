import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/config/oauth_config.dart';

void main() {
  group('OauthConfig Apple Android', () {
    test('Services ID and redirect URI are configured', () {
      expect(OauthConfig.appleServicesId, 'net.lotlot.bistpattern.web');
      expect(
        OauthConfig.appleAndroidRedirectUri,
        'https://lotlot.net/callbacks/sign_in_with_apple',
      );
      expect(OauthConfig.isAppleAndroidConfigured, isTrue);
    });
  });

  group('OauthConfig Google', () {
    test('Android and legacy server clients stay in expected projects', () {
      expect(
        OauthConfig.googleAndroidClientId,
        startsWith('202330846225-'),
      );
      expect(
        OauthConfig.googleAndroidServerClientId,
        startsWith('202330846225-'),
      );
      expect(
        OauthConfig.googleServerClientId,
        startsWith('544107298661-'),
      );
      expect(
        OauthConfig.googleIosClientId,
        startsWith('544107298661-'),
      );
      expect(OauthConfig.isGoogleConfigured, isTrue);
    });

    test('googleIosUrlScheme matches reversed client id prefix', () {
      final scheme = OauthConfig.googleIosUrlScheme;
      expect(scheme, isNotNull);
      expect(scheme, startsWith('com.googleusercontent.apps.'));
      expect(
        scheme!.contains('dn3bnerlqubij3vl4palru1ohv0sb55d'),
        isTrue,
      );
    });
  });
}
