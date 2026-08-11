import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
    this.errorCode,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  /// API `error` alanı — örn. `invalid_turnstile`, `email_not_verified`.
  final String? errorCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Lotlot JSON API istemcisi — Bearer + 401 refresh.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    http.Client? httpClient,
  })  : _tokens = tokenStorage,
        _http = httpClient ?? http.Client();

  final TokenStorage _tokens;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('DELETE', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final access = await _tokens.readAccessToken();
      if (access != null && access.isNotEmpty) {
        headers['Authorization'] = 'Bearer $access';
      }
    }

    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _http.get(uri, headers: headers);
      case 'POST':
        response = await _http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        response = await _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        response = await _http.delete(uri, headers: headers, body: encoded);
      default:
        throw UnsupportedError('HTTP $method desteklenmiyor');
    }

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
          retried: true,
        );
      }
    }

    Map<String, dynamic>? decoded;
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } on FormatException {
        // nginx 429 vb. HTML dönebilir; JSON bekleyen istemciyi çökertme.
        throw ApiException(
          statusCode: response.statusCode,
          message: _httpFallbackMessage(response.statusCode),
          errorCode: response.statusCode == 429
              ? 'rate_limited'
              : 'invalid_response',
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: decoded?['message']?.toString() ??
          decoded?['error']?.toString() ??
          _httpFallbackMessage(response.statusCode),
      body: decoded,
      errorCode: decoded?['error']?.toString() ??
          (response.statusCode == 429 ? 'rate_limited' : null),
    );
  }

  static String _httpFallbackMessage(int statusCode) {
    if (statusCode == 429) {
      return 'Çok hızlı istek gönderildi. Biraz bekleyip tekrar deneyin.';
    }
    return 'İstek başarısız';
  }

  /// `POST /api/auth/refresh` — §7
  Future<bool> refreshAccessToken() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final data = await post(
        '/api/auth/refresh',
        body: {'refresh_token': refresh},
        auth: false,
      );
      final access = data['access_token']?.toString();
      final newRefresh = data['refresh_token']?.toString() ?? refresh;
      if (access == null || access.isEmpty) return false;
      await _tokens.saveTokens(accessToken: access, refreshToken: newRefresh);
      return true;
    } on ApiException {
      await _tokens.clear();
      return false;
    }
  }

  /// `GET /api/auth/me` — §4 / §9
  Future<Map<String, dynamic>> fetchMe() => get('/api/auth/me');

  /// `PATCH /api/auth/me` — §8 (bildirim tercihleri)
  Future<Map<String, dynamic>> patchMe({
    bool? pushNotifications,
    bool? emailNotifications,
  }) {
    final body = <String, dynamic>{};
    if (pushNotifications != null) {
      body['push_notifications'] = pushNotifications;
    }
    if (emailNotifications != null) {
      body['email_notifications'] = emailNotifications;
    }
    return patch('/api/auth/me', body: body);
  }

  /// `POST /api/auth/login` — §6
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? turnstileToken,
  }) {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (turnstileToken != null) {
      body['turnstile_token'] = turnstileToken;
    }
    return post('/api/auth/login', body: body, auth: false);
  }

  /// `POST /api/auth/register` — §5 (`client: mobile`)
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? turnstileToken,
  }) {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'client': 'mobile',
    };
    if (turnstileToken != null) {
      body['turnstile_token'] = turnstileToken;
    }
    return post('/api/auth/register', body: body, auth: false);
  }

  /// `POST /api/auth/resend-verification` — §5
  Future<Map<String, dynamic>> resendVerification({required String email}) {
    return post(
      '/api/auth/resend-verification',
      body: {'email': email, 'client': 'mobile'},
      auth: false,
    );
  }

  /// `POST /api/auth/forgot-password` — §6.1 (`client: mobile`)
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
    String? turnstileToken,
  }) {
    final body = <String, dynamic>{
      'email': email,
      'client': 'mobile',
    };
    if (turnstileToken != null) {
      body['turnstile_token'] = turnstileToken;
    }
    return post('/api/auth/forgot-password', body: body, auth: false);
  }

  /// `DELETE /api/auth/me` — §8 (`confirm: true` zorunlu)
  Future<Map<String, dynamic>> deleteAccount() {
    return delete('/api/auth/me', body: {'confirm': true});
  }

  /// `POST /api/auth/google-mobile` — §8.4
  /// Yeni Google hesapta `turnstile_token` gerekir (`signup_turnstile_required`).
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? turnstileToken,
  }) {
    final body = <String, dynamic>{'idToken': idToken};
    if (turnstileToken != null && turnstileToken.isNotEmpty) {
      body['turnstile_token'] = turnstileToken;
    }
    return post(
      '/api/auth/google-mobile',
      body: body,
      auth: false,
    );
  }

  /// `POST /api/auth/apple-mobile` — §8.5
  Future<Map<String, dynamic>> loginWithApple({
    required String identityToken,
    Map<String, String?>? fullName,
  }) {
    final body = <String, dynamic>{
      'identityToken': identityToken,
    };
    if (fullName != null) {
      body['fullName'] = fullName;
    }
    return post(
      '/api/auth/apple-mobile',
      body: body,
      auth: false,
    );
  }

  Future<void> persistAuthResponse(Map<String, dynamic> data) async {
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    if (access == null || refresh == null) {
      throw ApiException(
        statusCode: 500,
        message: 'Token yanıtı eksik',
        body: data,
      );
    }
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
  }

  /// Logout: refresh revoke + yerel wipe (§8).
  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    try {
      await post(
        '/api/auth/logout',
        body: {
          if (refresh != null && refresh.isNotEmpty) 'refresh_token': refresh,
        },
        auth: false,
      );
    } catch (_) {
      // Yerel oturumu yine de temizle
    }
    await _tokens.clear();
  }

  /// `GET /api/stocks` — §17 (auth-free, tam katalog)
  Future<Map<String, dynamic>> fetchStocksCatalog() {
    return get('/api/stocks', auth: false);
  }

  /// `GET /api/stocks/search?q=` — §17 (auth-free)
  Future<Map<String, dynamic>> searchStocks(String query) {
    return get(
      '/api/stocks/search',
      query: {'q': query},
      auth: false,
    );
  }

  /// `GET /api/public/index-screener?index=` — §17.4 (auth-free)
  Future<Map<String, dynamic>> fetchIndexScreener(String index) {
    return get(
      '/api/public/index-screener',
      query: {'index': index},
      auth: false,
    );
  }

  /// `GET /api/watchlist` — §10
  Future<Map<String, dynamic>> fetchWatchlist() => get('/api/watchlist');

  /// `POST /api/watchlist` — §11
  Future<Map<String, dynamic>> addWatchlist({
    required String symbol,
    String? notes,
    bool alertEnabled = true,
  }) {
    return post('/api/watchlist', body: {
      'symbol': symbol,
      'alert_enabled': alertEnabled,
      'notes': ?notes,
    });
  }

  /// `DELETE /api/watchlist/<symbol>` — §13
  Future<Map<String, dynamic>> removeWatchlist(String symbol) {
    return delete('/api/watchlist/${Uri.encodeComponent(symbol)}');
  }

  /// `PATCH /api/watchlist/<symbol>` — §12 (F2 UI kullanmaz; helper hazır)
  Future<Map<String, dynamic>> patchWatchlist(
    String symbol, {
    Map<String, dynamic>? body,
  }) {
    return patch(
      '/api/watchlist/${Uri.encodeComponent(symbol)}',
      body: body,
    );
  }

  /// `GET /api/watchlist/predictions` — §14
  Future<Map<String, dynamic>> fetchWatchlistPredictions() {
    return get('/api/watchlist/predictions');
  }

  /// `GET /api/stocks/<sym>/volume-tier` — auth-free (§17 / guide)
  Future<Map<String, dynamic>> fetchVolumeTier(String symbol) {
    return get(
      '/api/stocks/${Uri.encodeComponent(symbol)}/volume-tier',
      auth: false,
    );
  }

  /// `GET /api/public/stocks/<sym>/valuation` — §17.2 (auth-free)
  Future<Map<String, dynamic>> fetchPublicValuation(String symbol) {
    return get(
      '/api/public/stocks/${Uri.encodeComponent(symbol)}/valuation',
      auth: false,
    );
  }

  /// `GET /api/public/stocks/<sym>/fundamentals` — §17.2.1 (auth-free)
  Future<Map<String, dynamic>> fetchPublicFundamentals(String symbol) {
    return get(
      '/api/public/stocks/${Uri.encodeComponent(symbol)}/fundamentals',
      auth: false,
    );
  }

  /// `GET /api/public/stocks/<sym>/corporate` — §17.2.2 (auth-free)
  Future<Map<String, dynamic>> fetchPublicCorporate(String symbol) {
    return get(
      '/api/public/stocks/${Uri.encodeComponent(symbol)}/corporate',
      auth: false,
    );
  }

  /// `GET /api/public/chart-data/<sym>?bars=` — §17.1 (auth-free)
  Future<Map<String, dynamic>> fetchPublicChartData(
    String symbol, {
    int bars = 180,
  }) {
    return get(
      '/api/public/chart-data/${Uri.encodeComponent(symbol)}',
      query: {'bars': '$bars'},
      auth: false,
    );
  }

  /// `GET /api/chart-data/<sym>?bars=` — §16.2 (Bearer)
  Future<Map<String, dynamic>> fetchChartData(
    String symbol, {
    int bars = 420,
  }) {
    return get(
      '/api/chart-data/${Uri.encodeComponent(symbol)}',
      query: {'bars': '$bars'},
    );
  }

  /// `GET /api/pattern-analysis/<sym>?fast=1` — §16.1 (Bearer)
  Future<Map<String, dynamic>> fetchPatternAnalysis(
    String symbol, {
    bool fast = true,
  }) {
    return get(
      '/api/pattern-analysis/${Uri.encodeComponent(symbol)}',
      query: {'fast': fast ? '1' : '0'},
    );
  }

  /// `GET /api/chart-alerts/limits` — §18.3 (Pro+)
  Future<Map<String, dynamic>> fetchChartAlertLimits() {
    return get('/api/chart-alerts/limits');
  }

  /// `GET /api/chart-alerts` — §18.3
  Future<Map<String, dynamic>> fetchChartAlerts({String? symbol}) {
    return get(
      '/api/chart-alerts',
      query: symbol != null ? {'symbol': symbol} : null,
    );
  }

  /// `POST /api/chart-alerts` — §18.3
  Future<Map<String, dynamic>> createChartAlert(Map<String, dynamic> body) {
    return post('/api/chart-alerts', body: body);
  }

  /// `DELETE /api/chart-alerts/<id>` — §18.3
  Future<Map<String, dynamic>> deleteChartAlert(String id) {
    return delete('/api/chart-alerts/${Uri.encodeComponent(id)}');
  }

  /// `POST /api/ai/commentary` — §18.1 (Pro); always async poll mode.
  ///
  /// Cache hit: `200` `{ status: success, text, cached }`.
  /// Miss: `202` `{ status: accepted, job_id, poll_after_ms }`.
  Future<Map<String, dynamic>> fetchAiCommentary({
    required String symbol,
    int bars = 300,
  }) {
    return post(
      '/api/ai/commentary',
      body: {
        'symbol': symbol.toUpperCase(),
        'bars': bars.clamp(120, 900),
        'async': true,
      },
    );
  }

  /// `GET /api/ai/commentary/jobs/<job_id>` — §18.1 poll (body `status`).
  Future<Map<String, dynamic>> fetchAiCommentaryJob(String jobId) {
    return get(
      '/api/ai/commentary/jobs/${Uri.encodeComponent(jobId)}',
    );
  }

  /// `POST /api/watchlist/wizard/recommendations` — §18.2 (Premium)
  Future<Map<String, dynamic>> fetchWizardRecommendations({
    required List<String> horizons,
    required List<String> signalTypes,
    String universe = 'all',
    int limit = 5,
    int daysBack = 7,
  }) {
    return post(
      '/api/watchlist/wizard/recommendations',
      body: {
        'horizons': horizons,
        'signal_types': signalTypes,
        'universe': universe,
        'limit': limit.clamp(1, 10),
        'days_back': daysBack.clamp(1, 30),
      },
    );
  }

  /// `POST /api/notifications/device/register` — §25 (Premium)
  Future<Map<String, dynamic>> registerDevice({
    required String token,
    required String platform,
  }) {
    return post(
      '/api/notifications/device/register',
      body: {'token': token, 'platform': platform},
    );
  }

  /// `POST /api/notifications/device/unregister` — §25
  Future<Map<String, dynamic>> unregisterDevice({String? token}) {
    return post(
      '/api/notifications/device/unregister',
      body: {'token': ?token},
    );
  }

  /// `GET /api/notifications/inbox` — §25.4 (Premium + push on)
  Future<Map<String, dynamic>> fetchNotificationInbox({
    int limit = 50,
    String? cursor,
  }) {
    final query = <String, String>{
      'limit': '${limit.clamp(1, 100)}',
    };
    if (cursor != null && cursor.isNotEmpty) {
      query['cursor'] = cursor;
    }
    return get('/api/notifications/inbox', query: query);
  }

  /// `GET /api/notifications/inbox/summary` — §25.4
  Future<Map<String, dynamic>> fetchNotificationInboxSummary() {
    return get('/api/notifications/inbox/summary');
  }

  /// `POST /api/notifications/inbox/<id>/read` — §25.4
  Future<Map<String, dynamic>> markInboxRead(String id) {
    return post(
      '/api/notifications/inbox/${Uri.encodeComponent(id)}/read',
    );
  }

  /// `POST /api/notifications/inbox/read-all` — §25.4
  Future<Map<String, dynamic>> markInboxReadAll() {
    return post('/api/notifications/inbox/read-all');
  }

  /// `DELETE /api/notifications/inbox/<id>` — §25.4
  Future<Map<String, dynamic>> deleteInboxItem(String id) {
    return delete(
      '/api/notifications/inbox/${Uri.encodeComponent(id)}',
    );
  }

  /// `POST /api/notifications/inbox/clear` — §25.4
  Future<Map<String, dynamic>> clearInbox() {
    return post('/api/notifications/inbox/clear');
  }

  /// `GET /api/billing/iap/config` — §9.8 (public)
  Future<Map<String, dynamic>> fetchIapConfig() {
    return get('/api/billing/iap/config', auth: false);
  }

  /// `POST /api/billing/iap/verify` — §9.4 / §9.5
  Future<Map<String, dynamic>> verifyIap({
    required String platform,
    required String productId,
    String? signedTransaction,
    String? purchaseToken,
  }) {
    final body = <String, dynamic>{
      'platform': platform,
      'product_id': productId,
    };
    if (signedTransaction != null) {
      body['signed_transaction'] = signedTransaction;
    }
    if (purchaseToken != null) {
      body['purchase_token'] = purchaseToken;
    }
    return post('/api/billing/iap/verify', body: body);
  }

  /// `POST /api/billing/iap/restore` — §9.8
  Future<Map<String, dynamic>> restoreIap({
    required String platform,
    List<String>? signedTransactions,
    List<Map<String, String>>? purchases,
  }) {
    final body = <String, dynamic>{'platform': platform};
    if (signedTransactions != null) {
      body['signed_transactions'] = signedTransactions;
    }
    if (purchases != null) {
      body['purchases'] = purchases;
    }
    return post('/api/billing/iap/restore', body: body);
  }
}
