import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// iOS/Android application icon badge (§25.4 P0/P1).
class AppBadge {
  AppBadge._();

  static Future<void> clear() => set(0);

  static Future<void> set(int count) async {
    final n = count < 0 ? 0 : count;
    try {
      if (!await AppBadgePlus.isSupported()) return;
      await AppBadgePlus.updateBadge(n);
    } catch (e) {
      debugPrint('AppBadge.set($n): $e');
    }
  }
}
