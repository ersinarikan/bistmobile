/// lotlot.net yasal sayfaları (F4 — dış tarayıcı).
abstract final class LegalUrls {
  static const gizlilik = 'https://lotlot.net/gizlilik';
  static const privacy = 'https://lotlot.net/privacy';
  static const terms = 'https://lotlot.net/terms';
}

/// Auth web formları (JSON API yok — guide §6.1).
abstract final class AuthWebUrls {
  /// GET only — POST `/forgot-password` form burada; doğrudan `/forgot-password` 405.
  static const forgotPassword =
      'https://lotlot.net/login?panel=forgot-password';
}
