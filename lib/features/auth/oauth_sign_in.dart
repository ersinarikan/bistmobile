import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/oauth_config.dart';

class OauthSignInException implements Exception {
  OauthSignInException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Native Google / Apple → backend’e gidecek token’lar (§8.4–§8.5).
class OauthSignIn {
  OauthSignIn._();

  static bool _googleReady = false;

  static Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    if (!OauthConfig.isGoogleConfigured) {
      throw OauthSignInException(
        'Google Client ID tanımlı değil. '
        'lib/core/config/oauth_config.dart içindeki OauthLocal alanlarını doldurun '
        'veya --dart-define kullanın.',
      );
    }
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS
          ? (OauthConfig.googleIosClientId.isEmpty
              ? null
              : OauthConfig.googleIosClientId)
          : (OauthConfig.googleAndroidClientId.isEmpty
              ? null
              : OauthConfig.googleAndroidClientId),
      serverClientId: OauthConfig.googleServerClientId.isEmpty
          ? null
          : OauthConfig.googleServerClientId,
    );
    _googleReady = true;
  }

  /// Google Sign-In → `idToken` (Turnstile yok).
  static Future<String> googleIdToken() async {
    await _ensureGoogle();
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw OauthSignInException(
          'Google idToken alınamadı. serverClientId (Web client) tanımlı mı?',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw OauthSignInException('Google girişi iptal edildi.');
      }
      throw OauthSignInException(
        'Google girişi başarısız: ${e.description ?? e.code.name}',
      );
    }
  }

  /// Sign in with Apple → identityToken + isteğe bağlı isim.
  static Future<({String identityToken, Map<String, String?>? fullName})>
      appleIdentity() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      throw OauthSignInException(
        'Apple ile giriş yalnızca iOS/macOS üzerinde kullanılabilir.',
      );
    }
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw OauthSignInException('Bu cihazda Sign in with Apple yok.');
    }

    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = cred.identityToken;
      if (token == null || token.isEmpty) {
        throw OauthSignInException('Apple identityToken alınamadı.');
      }

      Map<String, String?>? fullName;
      final given = cred.givenName;
      final family = cred.familyName;
      if ((given != null && given.isNotEmpty) ||
          (family != null && family.isNotEmpty)) {
        fullName = {
          'givenName': given,
          'familyName': family,
        };
      }
      return (identityToken: token, fullName: fullName);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw OauthSignInException('Apple girişi iptal edildi.');
      }
      throw OauthSignInException('Apple girişi başarısız: ${e.message}');
    }
  }
}