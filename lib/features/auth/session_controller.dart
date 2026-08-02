import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

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

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    lastError = null;
    notifyListeners();
    try {
      final data = await _api.login(email: email, password: password);
      // captcha_required ise UI Turnstile köprüsünü açacak (sonraki sprint)
      if (data['captcha_required'] == true ||
          data['error']?.toString() == 'captcha_required') {
        lastError = 'Doğrulama gerekli (Turnstile). Sonraki adımda eklenecek.';
        notifyListeners();
        return false;
      }
      await _api.persistAuthResponse(data);
      final me = data['user'] != null ? data : await _api.fetchMe();
      _applyMe(me);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
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
}
