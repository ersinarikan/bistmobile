import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

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
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _http.get(uri, headers: headers);
      case 'POST':
        response = await _http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
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
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: decoded?['message']?.toString() ??
          decoded?['error']?.toString() ??
          'İstek başarısız',
      body: decoded,
    );
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

  Future<void> logout() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {
      // Yerel oturumu yine de temizle
    }
    await _tokens.clear();
  }
}
