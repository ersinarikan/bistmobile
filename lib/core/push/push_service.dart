import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api_client.dart';
import '../navigation/deep_link_router.dart';
import 'apns_token_wait.dart';

/// FCM lifecycle — Firebase yoksa no-op (crash yok).
class PushService extends ChangeNotifier {
  PushService({
    required ApiClient apiClient,
    this._readApnsToken,
    this._readFcmToken,
    this._ensurePermissionOverride,
    bool? isIos,
    this._apnsRetryDelay = const Duration(milliseconds: 400),
    this._apnsMaxAttempts = 10,
  })  : _api = apiClient,
        _isIosOverride = isIos;

  final ApiClient _api;
  final Future<String?> Function()? _readApnsToken;
  final Future<String?> Function()? _readFcmToken;
  final Future<bool> Function()? _ensurePermissionOverride;
  final bool? _isIosOverride;
  final Duration _apnsRetryDelay;
  final int _apnsMaxAttempts;

  bool firebaseReady = false;
  bool permissionGranted = false;
  String? lastToken;
  String? lastError;
  String? statusMessage;
  StreamSubscription<String>? _tokenSub;
  bool _syncing = false;

  bool get _isIos => _isIosOverride ?? Platform.isIOS;

  void attachMessagingHandlers() {
    if (!firebaseReady) return;
    FirebaseMessaging.onMessage.listen((msg) {
      showFcmForegroundSnack(
        Map<String, dynamic>.from(msg.data),
        title: msg.notification?.title,
        body: msg.notification?.body,
      );
    });
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      lastToken = token;
      // Caller should re-sync; notify so UI/session can react.
      notifyListeners();
    });
  }

  Future<bool> ensurePermission() async {
    final permissionOverride = _ensurePermissionOverride;
    if (permissionOverride != null) {
      permissionGranted = await permissionOverride();
      notifyListeners();
      return permissionGranted;
    }
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      permissionGranted = status.isGranted;
    } else {
      if (!firebaseReady) {
        permissionGranted = false;
        return false;
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    notifyListeners();
    return permissionGranted;
  }

  Future<String?> fetchToken() async {
    if (!firebaseReady) return null;
    try {
      // iOS: FCM token requires APNs token first (often null right after grant).
      if (_isIos) {
        final apns = await waitForApnsToken(
          readToken: _readApnsToken ??
              () => FirebaseMessaging.instance.getAPNSToken(),
          maxAttempts: _apnsMaxAttempts,
          delay: _apnsRetryDelay,
        );
        if (apns == null || apns.isEmpty) {
          lastError = 'apns_token_unavailable';
          debugPrint('PushService.fetchToken: APNs token not ready');
          return null;
        }
      }
      final readFcm =
          _readFcmToken ?? () => FirebaseMessaging.instance.getToken();
      lastToken = await readFcm();
      return lastToken;
    } catch (e) {
      lastError = e.toString();
      debugPrint('PushService.fetchToken: $e');
      return null;
    }
  }

  /// Premium + push_notifications açıkken register.
  Future<bool> syncRegistration({
    required bool isPremium,
    required bool pushOn,
  }) async {
    if (_syncing) return false;
    _syncing = true;
    try {
      if (!isPremium || !pushOn) {
        await unregisterQuiet(clearAll: true);
        statusMessage = null;
        notifyListeners();
        return false;
      }
      if (!firebaseReady) {
        statusMessage =
            'Firebase yapılandırması eksik (GoogleService-Info.plist).';
        debugPrint('PushService: Firebase not ready; device register skipped');
        notifyListeners();
        return false;
      }
      final okPerm = await ensurePermission();
      if (!okPerm) {
        statusMessage = 'Bildirim izni verilmedi.';
        notifyListeners();
        return false;
      }
      final token = await fetchToken();
      if (token == null || token.length < 20) {
        statusMessage =
            'FCM token alınamadı. Bildirim izni ve APNs/Firebase ayarını kontrol edin.';
        debugPrint('PushService: token missing or too short');
        notifyListeners();
        return false;
      }
      try {
        final platform = _isIos ? 'ios' : 'android';
        await _api.registerDevice(token: token, platform: platform);
        statusMessage = 'Bildirim kaydı tamam.';
        lastError = null;
        notifyListeners();
        return true;
      } on ApiException catch (e) {
        lastError = e.message;
        statusMessage = e.errorCode == 'push_disabled'
            ? 'Hesap bildirimi kapalı; kayıt yapılmadı.'
            : e.message;
        notifyListeners();
        return false;
      }
    } finally {
      _syncing = false;
    }
  }

  /// Logout: tüm cihaz tokenlarını temizle (token yoksa body boş).
  Future<void> unregisterQuiet({bool clearAll = false}) async {
    try {
      if (clearAll || lastToken == null) {
        await _api.unregisterDevice();
      } else {
        await _api.unregisterDevice(token: lastToken);
      }
    } catch (_) {}
    lastToken = null;
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan: sistem tepsisi yeter; deep_link cold-start main’de işlenir.
}
