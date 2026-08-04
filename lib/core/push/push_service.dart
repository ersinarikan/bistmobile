import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api_client.dart';
import '../navigation/deep_link_router.dart';

/// FCM lifecycle — Firebase yoksa no-op (crash yok).
class PushService extends ChangeNotifier {
  PushService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  bool firebaseReady = false;
  bool permissionGranted = false;
  String? lastToken;
  String? lastError;
  String? statusMessage;
  StreamSubscription<String>? _tokenSub;
  bool _syncing = false;

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
      lastToken = await FirebaseMessaging.instance.getToken();
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
        statusMessage = 'Bildirimler şu an kurulamadı.';
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
        statusMessage = 'Bildirimler şu an kurulamadı.';
        debugPrint('PushService: token missing or too short');
        notifyListeners();
        return false;
      }
      try {
        final platform = Platform.isIOS ? 'ios' : 'android';
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
