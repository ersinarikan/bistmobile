import '../../core/api/api_client.dart';
import 'session_controller.dart';

/// §6.1 forgot-password hata → [PasswordResetResult] (birim test için saf).
PasswordResetResult mapForgotPasswordException(ApiException e) {
  final code = e.errorCode;
  final captchaFlag = e.body?['captcha_required'] == true;
  if (code == 'captcha_required' ||
      code == 'invalid_turnstile' ||
      captchaFlag ||
      (e.statusCode == 400 &&
          (e.message.toLowerCase().contains('turnstile')))) {
    return PasswordResetResult.needsTurnstile;
  }
  return PasswordResetResult.failed;
}

/// Auth ekranı ortak Turnstile / reset kopyaları (S1192).
abstract final class AuthCopy {
  static const turnstileRequired =
      'Güvenlik doğrulaması gerekli. Lütfen tekrar deneyin.';
  static const turnstileRetry =
      'Güvenlik doğrulaması yenilenmeli. Lütfen tekrar deneyin.';
  static const passwordResetSent =
      'Bu e-postaya ait aktif bir hesap varsa şifre sıfırlama '
      'bağlantısı gönderildi. Maildeki linki tarayıcıda açın.';
  static const passwordResetDone = 'Şifreniz güncellendi — giriş yapın.';
}

/// `lotlot://auth/login?password_reset=…` bayrağı.
bool isPasswordResetQuery(Map<String, String> query) {
  final raw = (query['password_reset'] ?? '').toLowerCase();
  return raw == '1' || raw == 'true' || raw == 'yes';
}

/// Yalnızca lotlot.net bridge + Cloudflare Turnstile navigasyonu.
bool isAllowedTurnstileNavigation(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'about' || scheme == 'data') return true;
  if (scheme != 'https' && scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (host == 'lotlot.net' || host == 'www.lotlot.net') return true;
  if (host == 'challenges.cloudflare.com') return true;
  if (host.endsWith('.cloudflare.com')) return true;
  return false;
}
