import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/api_client.dart';

/// FCM lifecycle — Firebase yoksa no-op (crash yok).
class PushService extends ChangeNotifier {
  PushService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  bool firebaseReady = false;
  bool permissionGranted = false;
  String? lastToken;
  String? lastError;
  String? statusMessage;

  Future<void> initFirebase() async {
    lastError = null;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      firebaseReady = true;
      statusMessage = null;
      FirebaseMessaging.onMessage.listen((_) {});
    } catch (e) {
      firebaseReady = false;
      statusMessage =
          'Firebase yapılandırılmadı (google-services / GoogleService-Info).';
      debugPrint('PushService.initFirebase: $e');
    }
    notifyListeners();
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
    if (!isPremium || !pushOn) {
      await unregisterQuiet();
      return false;
    }
    if (!firebaseReady) {
      statusMessage =
          'Firebase yapılandırılmadı; cihaz kaydı atlandı.';
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
      statusMessage = 'FCM token alınamadı.';
      notifyListeners();
      return false;
    }
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _api.registerDevice(token: token, platform: platform);
      statusMessage = 'Cihaz kaydı tamam.';
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      statusMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> unregisterQuiet() async {
    final token = lastToken;
    try {
      await _api.unregisterDevice(token: token);
    } catch (_) {}
    lastToken = null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan: sistem tepsisi yeter; deep_link cold-start main’de işlenir.
}
