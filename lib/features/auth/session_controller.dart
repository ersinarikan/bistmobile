import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

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

  void setError(String? message) {
    lastError = message;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    status = AuthStatus.unknown;
    lastError = null;
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
        status = AuthStatus.unauthenticated;
        user = null;
        subscription = null;
      } else {
        lastError = e.message;
        status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      lastError = e.toString();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
    String? turnstileToken,
  }) async {
    lastError = null;
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
      if (code == 'captcha_required' || e.body?['captcha_required'] == true) {
        lastError = null;
        notifyListeners();
        return LoginResult.needsTurnstile;
      }
      if (code == 'email_not_verified' ||
          (e.statusCode == 403 && e.body?['verification_required'] == true)) {
        lastError = e.message.isNotEmpty
            ? e.message
            : 'E-posta henüz doğrulanmadı.';
        notifyListeners();
        return LoginResult.emailNotVerified;
      }
      lastError = _friendlyAuthMessage(e);
      notifyListeners();
      return LoginResult.failed;
    } catch (e) {
      lastError = e.toString();
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
      notifyListeners();
      return RegisterResult.failed;
    } catch (e) {
      lastError = e.toString();
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
    notifyListeners();
    try {
      final data = await _api.resendVerification(email: email);
      lastError = data['message']?.toString();
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

  Future<void> logout() async {
    await _api.logout();
    user = null;
    subscription = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
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
      case 'invalid_oauth_token':
        return 'Apple/Google doğrulanamadı. Biraz sonra tekrar deneyin.';
      case 'id_token_required':
        return 'OAuth token eksik.';
      case 'identity_token_required':
        return 'Apple token eksik.';
      case 'inactive_user':
        return 'Hesap pasif. Destek ile iletişime geçin.';
      case 'invalid_turnstile':
        return 'Güvenlik doğrulaması geçersiz veya süresi doldu. Tekrar deneyin.';
      default:
        return e.message;
    }
  }
}
