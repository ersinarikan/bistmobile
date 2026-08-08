import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'auth_helpers.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum LoginResult {
  success,
  failed,
  needsTurnstile,
  emailNotVerified,
}

enum RegisterResult {
  pendingVerification,
  needsTurnstile,
  failed,
}

enum PasswordResetResult {
  success,
  needsTurnstile,
  failed,
}

/// Oturum + `/api/auth/me` subscription state.
class SessionController extends ChangeNotifier {
  SessionController({
    required TokenStorage tokenStorage,
    required ApiClient apiClient,
  })  : _tokens = tokenStorage,
        _api = apiClient;

  final TokenStorage _tokens;
  final ApiClient _api;

  AuthStatus status = AuthStatus.unknown;
  Map<String, dynamic>? user;
  Map<String, dynamic>? subscription;
  String? lastError;

  bool get isPro => subscription?['is_pro'] == true;
  bool get isPremium => subscription?['is_premium'] == true;
  bool get pushNotificationsOn => user?['push_notifications'] == true;
  String? get userId {
    final id = user?['id'];
    if (id == null) return null;
    return id.toString();
  }

  /// Son API `error` kodu (UI CTA için — örn. email_already_registered).
  String? lastErrorCode;

  /// Son register/resend yanıtındaki `verification_email_sent` (§5).
  bool? lastVerificationEmailSent;

  void setError(String? message, {String? errorCode}) {
    lastError = message;
    lastErrorCode = errorCode;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    status = AuthStatus.unknown;
    lastError = null;
    lastErrorCode = null;
    notifyListeners();

    final access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final me = await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _tokens.clear();
        status = AuthStatus.unauthenticated;
        user = null;
        subscription = null;
      } else {
        // Geçici ağ/5xx: token kalsın; splash’ta Yeniden dene (P3).
        lastError = e.message.isNotEmpty
            ? e.message
            : 'Bağlantı kurulamadı. Tekrar deneyin.';
        lastErrorCode = e.errorCode;
        status = AuthStatus.unknown;
        user = null;
        subscription = null;
      }
    } catch (e) {
      lastError = 'Bağlantı kurulamadı. Tekrar deneyin.';
      status = AuthStatus.unknown;
      user = null;
      subscription = null;
    }
    notifyListeners();
  }

  /// Splash soft-fail: token silmeden misafir shell (P3).
  void continueAsGuestKeepingTokens() {
    status = AuthStatus.unauthenticated;
    user = null;
    subscription = null;
    lastError = null;
    lastErrorCode = null;
    notifyListeners();
  }

  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
    String? turnstileToken,
  }) async {
    lastError = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      final data = await _api.login(
        email: email,
        password: password,
        turnstileToken: turnstileToken,
      );
      await _api.persistAuthResponse(data);
      final me = data['user'] != null ? data : await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
      notifyListeners();
      return LoginResult.success;
    } on ApiException catch (e) {
      final code = e.errorCode;
      final captchaFlag = e.body?['captcha_required'] == true;
      // Pure captcha_required (400) veya invalid_credentials + bayrak → köprü (guide §6).
      if (code == 'captcha_required' || captchaFlag) {
        if (code == 'invalid_credentials') {
          // P4: köprü açılırken yanlış şifre mesajını koru
          lastError = _friendlyAuthMessage(e);
          lastErrorCode = code;
        } else {
          lastError = null;
          lastErrorCode = code;
        }
        notifyListeners();
        return LoginResult.needsTurnstile;
      }
      if (code == 'email_not_verified' ||
          (e.statusCode == 403 && e.body?['verification_required'] == true)) {
        lastError = e.message.isNotEmpty
            ? e.message
            : 'E-posta henüz doğrulanmadı.';
        lastErrorCode = code;
        notifyListeners();
        return LoginResult.emailNotVerified;
      }
      lastError = _friendlyAuthMessage(e);
      lastErrorCode = code;
      notifyListeners();
      return LoginResult.failed;
    } catch (e) {
      lastError = e.toString();
      lastErrorCode = null;
      notifyListeners();
      return LoginResult.failed;
    }
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? turnstileToken,
  }) async {
    lastError = null;
    lastErrorCode = null;
    lastVerificationEmailSent = null;
    notifyListeners();
    try {
      final data = await _api.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        turnstileToken: turnstileToken,
      );
      // 201 pending_verification — JWT yok
      if (data['status']?.toString() == 'pending_verification' ||
          data['verification_required'] == true) {
        lastVerificationEmailSent = data['verification_email_sent'] == true;
        notifyListeners();
        return RegisterResult.pendingVerification;
      }
      lastError = data['message']?.toString() ?? 'Kayıt tamamlanamadı';
      notifyListeners();
      return RegisterResult.failed;
    } on ApiException catch (e) {
      // Prod ALWAYS: ilk token’sız deneme → invalid_turnstile (lazy köprü)
      if (e.errorCode == 'invalid_turnstile' ||
          (e.statusCode == 400 &&
              (e.message.toLowerCase().contains('turnstile')))) {
        lastError = null;
        notifyListeners();
        return RegisterResult.needsTurnstile;
      }
      lastError = _friendlyAuthMessage(e);
      lastErrorCode = e.errorCode;
      notifyListeners();
      return RegisterResult.failed;
    } catch (e) {
      lastError = e.toString();
      lastErrorCode = null;
      notifyListeners();
      return RegisterResult.failed;
    }
  }

  Future<LoginResult> loginWithGoogleIdToken(String idToken) async {
    lastError = null;
    notifyListeners();
    try {
      final data = await _api.loginWithGoogle(idToken: idToken);
      await _api.persistAuthResponse(data);
      final me = data['user'] != null ? data : await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
      notifyListeners();
      return LoginResult.success;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return LoginResult.failed;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return LoginResult.failed;
    }
  }

  Future<LoginResult> loginWithAppleIdentity({
    required String identityToken,
    Map<String, String?>? fullName,
  }) async {
    lastError = null;
    notifyListeners();
    try {
      final data = await _api.loginWithApple(
        identityToken: identityToken,
        fullName: fullName,
      );
      await _api.persistAuthResponse(data);
      final me = data['user'] != null ? data : await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
      notifyListeners();
      return LoginResult.success;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return LoginResult.failed;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return LoginResult.failed;
    }
  }

  Future<bool> resendVerification({required String email}) async {
    lastError = null;
    lastVerificationEmailSent = null;
    notifyListeners();
    try {
      final data = await _api.resendVerification(email: email);
      lastVerificationEmailSent = data['verification_email_sent'] == true;
      // Guide: 200 generic; mobilde sent bayrağına göre kopya ayır (R3b / V2)
      if (lastVerificationEmailSent == true) {
        lastError = data['message']?.toString() ??
            'Doğrulama e-postası gönderildi.';
      } else {
        lastError =
            'Doğrulama e-postası şu an gönderilemedi. Biraz sonra tekrar deneyin.';
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// `POST /api/auth/forgot-password` — §6.1 (yeni şifre web formunda).
  Future<PasswordResetResult> requestPasswordReset({
    required String email,
    String? turnstileToken,
  }) async {
    lastError = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      await _api.forgotPassword(
        email: email,
        turnstileToken: turnstileToken,
      );
      // Generic 200 — e-posta varlığı ifşa edilmez.
      notifyListeners();
      return PasswordResetResult.success;
    } on ApiException catch (e) {
      final mapped = mapForgotPasswordException(e);
      if (mapped == PasswordResetResult.needsTurnstile) {
        lastError =
            e.errorCode == 'invalid_turnstile' ? _friendlyAuthMessage(e) : null;
        lastErrorCode = e.errorCode;
        notifyListeners();
        return PasswordResetResult.needsTurnstile;
      }
      lastError = _friendlyAuthMessage(e);
      lastErrorCode = e.errorCode;
      notifyListeners();
      return PasswordResetResult.failed;
    } catch (e) {
      lastError = e.toString();
      lastErrorCode = null;
      notifyListeners();
      return PasswordResetResult.failed;
    }
  }

  Future<bool> deleteAccount() async {
    lastError = null;
    notifyListeners();
    try {
      await _api.deleteAccount();
      await _tokens.clear();
      user = null;
      subscription = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout öncesi (access token hâlâ geçerliyken) — örn. FCM unregister.
  Future<void> Function()? beforeLogout;

  Future<void> logout() async {
    final hook = beforeLogout;
    if (hook != null) {
      try {
        await hook();
      } catch (_) {
        // Local wipe yine de devam etsin.
      }
    }
    await _api.logout();
    user = null;
    subscription = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// `GET /api/auth/me` yenile — hesap ekranı.
  Future<bool> refreshMe() async {
    lastError = null;
    try {
      final me = await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// `PATCH /api/auth/me` bildirim tercihleri — F4 (FCM yok).
  Future<bool> updateNotificationPrefs({
    bool? pushNotifications,
    bool? emailNotifications,
  }) async {
    lastError = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      final me = await _api.patchMe(
        pushNotifications: pushNotifications,
        emailNotifications: emailNotifications,
      );
      _applyMe(me);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = _friendlyAuthMessage(e);
      lastErrorCode = e.errorCode;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _applyMe(Map<String, dynamic> me) {
    user = me['user'] as Map<String, dynamic>? ?? me;
    subscription = me['subscription'] as Map<String, dynamic>?;
  }

  String _friendlyAuthMessage(ApiException e) {
    switch (e.errorCode) {
      case 'invalid_credentials':
        return 'E-posta veya şifre hatalı.';
      case 'rate_limited':
        final sec = e.body?['retry_after_seconds'];
        return sec != null
            ? 'Çok fazla deneme. $sec sn sonra tekrar deneyin.'
            : 'Çok fazla deneme. Biraz sonra tekrar deneyin.';
      case 'email_exists':
      case 'already_registered':
      case 'email_already_registered':
        return 'Bu e-posta ile kayıtlı bir hesap var. Giriş yapmayı deneyin.';
      case 'email_and_password_required':
        return 'E-posta ve şifre gerekli.';
      case 'email_required':
        return 'E-posta gerekli.';
      case 'invalid_email':
        return 'Geçerli bir e-posta adresi girin.';
      case 'weak_password':
        return 'Şifre en az 8 karakter olmalı.';
      case 'register_failed':
      case 'server_error':
        return 'Kayıt şu an tamamlanamadı. Biraz sonra tekrar deneyin.';
      case 'invalid_oauth_token':
        return 'Apple/Google doğrulanamadı. Biraz sonra tekrar deneyin.';
      case 'oauth_failed':
        return 'Sosyal giriş tamamlanamadı. Tekrar deneyin.';
      case 'token_issue_failed':
        return 'Oturum açılamadı. Biraz sonra tekrar deneyin.';
      case 'id_token_required':
        return 'OAuth token eksik.';
      case 'identity_token_required':
        return 'Apple token eksik.';
      case 'premium_required':
        return 'Bu özellik Premium planında.';
      case 'pro_required':
        return 'Bu özellik Pro planında.';
      case 'inactive_user':
        return 'Hesap pasif. Destek ile iletişime geçin.';
      case 'invalid_turnstile':
        return 'Güvenlik doğrulaması geçersiz veya süresi doldu. Tekrar deneyin.';
      case 'captcha_required':
        return 'Güvenlik doğrulaması gerekli. Lütfen tekrar deneyin.';
      case 'email_not_verified':
        return e.message.isNotEmpty
            ? e.message
            : 'E-posta henüz doğrulanmadı.';
      case 'no_supported_fields':
        return 'Bu tercihler şu an güncellenemiyor.';
      default:
        return e.message.isNotEmpty ? e.message : 'İstek başarısız';
    }
  }
}
