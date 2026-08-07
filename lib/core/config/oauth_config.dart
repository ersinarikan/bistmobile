/// Google / Apple OAuth istemci kimlikleri (§8.4–§8.5).
///
/// Client ID’ler gizli değildir (uygulamada zaten görünür). Doldurun:
/// 1) Google Cloud Console → OAuth iOS + Android (+ Web/server for idToken)
/// 2) Backend `GOOGLE_MOBILE_CLIENT_IDS` = iOS,Android (virgülle)
/// 3) Backend `APPLE_MOBILE_CLIENT_IDS` = Bundle ID; `APPLE_CLIENT_ID` = Services ID
/// 4) Android Apple: Services ID Return URL = [appleAndroidRedirectUri]
///
/// Override: `--dart-define=GOOGLE_IOS_CLIENT_ID=...` vb.
class OauthConfig {
  /// Native iOS Sign in with Apple — JWT `aud` = Bundle ID.
  static const String appleBundleId = 'com.lotlot.lotlotnetMobile';

  /// Android/Web Sign in with Apple — JWT `aud` = Services ID (`APPLE_CLIENT_ID`).
  static const String appleServicesId = String.fromEnvironment(
    'APPLE_SERVICES_ID',
    defaultValue: OauthLocal.appleServicesId,
  );

  /// Android Chrome Custom Tab → sunucu → `signinwithapple://callback` köprüsü.
  static const String appleAndroidRedirectUri = String.fromEnvironment(
    'APPLE_ANDROID_REDIRECT_URI',
    defaultValue: OauthLocal.appleAndroidRedirectUri,
  );

  /// iOS OAuth client ID (`….apps.googleusercontent.com`).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: OauthLocal.googleIosClientId,
  );

  /// iOS / legacy web — idToken `aud` (GCP `544107298661`).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: OauthLocal.googleServerClientId,
  );

  /// Android Sign-In `serverClientId` — Firebase GCP `202330846225` Web client.
  /// Android OAuth client ile **aynı projede** olmalı (DEVELOPER_ERROR aksi halde).
  static const String googleAndroidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_SERVER_CLIENT_ID',
    defaultValue: OauthLocal.googleAndroidServerClientId,
  );

  /// Android OAuth client ID (package + SHA-1; Firebase projesi).
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: OauthLocal.googleAndroidClientId,
  );

  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty ||
      googleIosClientId.isNotEmpty ||
      googleAndroidClientId.isNotEmpty;

  static bool get isAppleAndroidConfigured =>
      appleServicesId.isNotEmpty && appleAndroidRedirectUri.isNotEmpty;

  /// iOS URL scheme: `com.googleusercontent.apps.<prefix>`
  static String? get googleIosUrlScheme {
    final id = googleIosClientId;
    if (id.isEmpty || !id.contains('.apps.googleusercontent.com')) {
      return null;
    }
    final prefix = id.split('.apps.googleusercontent.com').first;
    return 'com.googleusercontent.apps.$prefix';
  }
}

/// Yerel varsayılanlar — client ID’ler gizli değildir.
/// Web Google ID: lotlot.net `/auth/google` redirect’ten (2026-08-03).
/// Ayrı iOS/Android OAuth client’ları Google Cloud’da yoksa SDK için
/// iOS’ta ayrıca iOS-type client gerekir; backend çoğu kurulumda web ID’yi
/// `GOOGLE_CLIENT_ID` fallback ile kabul eder (§8.4).
class OauthLocal {
  /// Prod Apple Services ID (`APPLE_CLIENT_ID` / web + Android SIWA).
  static const String appleServicesId = 'net.lotlot.bistpattern.web';

  /// Must match Apple Developer → Services ID → Return URLs.
  static const String appleAndroidRedirectUri =
      'https://lotlot.net/callbacks/sign_in_with_apple';

  /// Google Cloud → iOS_mobile (Bundle: com.lotlot.lotlotnetMobile)
  static const String googleIosClientId =
      '544107298661-dn3bnerlqubij3vl4palru1ohv0sb55d.apps.googleusercontent.com';

  /// Web / server client — idToken audience (lotlot web login, eski GCP)
  static const String googleServerClientId =
      '544107298661-40cqi5v09peic8bqkmohl4rctuddgtms.apps.googleusercontent.com';

  /// Firebase/lotlotnet Web client — Android `serverClientId`
  static const String googleAndroidServerClientId =
      '202330846225-3o560nvert257irvvrsmgh19n644r010.apps.googleusercontent.com';

  static const String googleAndroidClientId =
      '202330846225-qhvl2p3i94nt76n05bg9dhr1gaqbtv29.apps.googleusercontent.com';
}
