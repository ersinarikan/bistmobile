/// Production base URL — preprod/HPO mobil istemci için kullanılmaz.
/// Kaynak: docs/MOBILE_API_INTEGRATION_GUIDE.md §2
class ApiConfig {
  static const String baseUrl = 'https://lotlot.net';
  static const String turnstileBridgeUrl = '$baseUrl/mobile/turnstile';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
