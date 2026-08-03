/// Google / Apple OAuth istemci kimlikleri (§8.4–§8.5).
///
/// Client ID’ler gizli değildir (uygulamada zaten görünür). Doldurun:
/// 1) Google Cloud Console → OAuth iOS + Android (+ Web/server for idToken)
/// 2) Backend `GOOGLE_MOBILE_CLIENT_IDS` = iOS,Android (virgülle)
/// 3) Backend `APPLE_CLIENT_ID` = `com.lotlot.lotlotnetMobile` (Bundle ID)
///
/// Override: `--dart-define=GOOGLE_IOS_CLIENT_ID=...` vb.
class OauthConfig {
  static const String appleBundleId = 'com.lotlot.lotlotnetMobile';

  /// iOS OAuth client ID (`….apps.googleusercontent.com`).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: OauthLocal.googleIosClientId,
  );

  /// Backend’e giden idToken `aud` için — genelde Web client ID
  /// (`GOOGLE_CLIENT_ID` / server client). Android’de zorunluya yakındır.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: OauthLocal.googleServerClientId,
  );

  /// Android OAuth client ID (isteğe bağlı; çoğu kurulumda server ID yeter).
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: OauthLocal.googleAndroidClientId,
  );

  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty ||
      googleIosClientId.isNotEmpty ||
      googleAndroidClientId.isNotEmpty;

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
  /// Google Cloud → iOS_mobile (Bundle: com.lotlot.lotlotnetMobile)
  static const String googleIosClientId =
      '544107298661-dn3bnerlqubij3vl4palru1ohv0sb55d.apps.googleusercontent.com';

  /// Web / server client — idToken audience (lotlot web login)
  static const String googleServerClientId =
      '544107298661-40cqi5v09peic8bqkmohl4rctuddgtms.apps.googleusercontent.com';

  static const String googleAndroidClientId = '';
}
