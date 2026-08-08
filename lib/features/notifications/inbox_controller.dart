import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/push/app_badge.dart';
import '../../core/push/push_service.dart';

class InboxItem {
  InboxItem({
    required this.id,
    required this.createdAt,
    this.readAt,
    this.type,
    this.symbol,
    this.horizon,
    this.titleTr,
    this.bodyTr,
    this.deepLink,
    this.dedupeKey,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      readAt: json['read_at']?.toString(),
      type: json['type']?.toString(),
      symbol: json['symbol']?.toString(),
      horizon: json['horizon']?.toString(),
      titleTr: json['title_tr']?.toString(),
      bodyTr: json['body_tr']?.toString(),
      deepLink: json['deep_link']?.toString(),
      dedupeKey: json['dedupe_key']?.toString(),
    );
  }

  final String id;
  final String? createdAt;
  final String? readAt;
  final String? type;
  final String? symbol;
  final String? horizon;
  final String? titleTr;
  final String? bodyTr;
  final String? deepLink;
  final String? dedupeKey;

  bool get isUnread => readAt == null || readAt!.isEmpty;

  InboxItem copyWith({String? readAt}) {
    return InboxItem(
      id: id,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      type: type,
      symbol: symbol,
      horizon: horizon,
      titleTr: titleTr,
      bodyTr: bodyTr,
      deepLink: deepLink,
      dedupeKey: dedupeKey,
    );
  }
}

/// §25.4 Gelen bildirimler — Premium + push_notifications.
class InboxController extends ChangeNotifier {
  InboxController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<InboxItem> items = const [];
  int unreadCount = 0;
  String? nextCursor;
  bool loading = false;
  String? error;
  DateTime? _lastSummaryAt;

  /// FCM/socket `unread_count` ipucu — profil + ikon badge anında (API SoT sonra).
  void applyUnreadHint(Object? raw) {
    final n = parsePushUnreadCount(raw);
    if (n == null) return;
    if (n == unreadCount) {
      unawaited(AppBadge.set(n));
      return;
    }
    unreadCount = n;
    unawaited(AppBadge.set(n));
    notifyListeners();
  }

  Future<void> refreshSummary({bool force = false}) async {
    if (!force &&
        _lastSummaryAt != null &&
        DateTime.now().difference(_lastSummaryAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    try {
      final data = await _api.fetchNotificationInboxSummary();
      final n = data['unread_count'];
      unreadCount = n is num ? n.toInt() : int.tryParse('$n') ?? 0;
      _lastSummaryAt = DateTime.now();
      error = null;
      await AppBadge.set(unreadCount);
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        unreadCount = 0;
        await AppBadge.clear();
        notifyListeners();
        return;
      }
      debugPrint('InboxController.refreshSummary: $e');
    } catch (e) {
      debugPrint('InboxController.refreshSummary: $e');
    }
  }

  Future<void> load({bool reset = true}) async {
    if (loading) return;
    loading = true;
    error = null;
    if (reset) {
      nextCursor = null;
    }
    notifyListeners();
    try {
      final data = await _api.fetchNotificationInbox(
        cursor: reset ? null : nextCursor,
      );
      final raw = data['items'];
      final list = <InboxItem>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(InboxItem.fromJson(e));
          } else if (e is Map) {
            list.add(InboxItem.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      items = reset ? list : [...items, ...list];
      final n = data['unread_count'];
      unreadCount = n is num ? n.toInt() : int.tryParse('$n') ?? unreadCount;
      nextCursor = data['next_cursor']?.toString();
      await AppBadge.set(unreadCount);
    } on ApiException catch (e) {
      error = e.message;
      if (e.statusCode == 403) {
        items = const [];
        unreadCount = 0;
        await AppBadge.clear();
      }
    } catch (e) {
      error = 'Bildirimler yüklenemedi.';
      debugPrint('InboxController.load: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    try {
      final data = await _api.markInboxRead(id);
      _applyUnread(data);
      items = [
        for (final it in items)
          if (it.id == id)
            it.copyWith(readAt: it.readAt ?? DateTime.now().toIso8601String())
          else
            it,
      ];
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint('InboxController.markRead: $e');
    }
  }

  Future<void> markReadAll() async {
    try {
      final data = await _api.markInboxReadAll();
      _applyUnread(data);
      final now = DateTime.now().toIso8601String();
      items = [for (final it in items) it.copyWith(readAt: it.readAt ?? now)];
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final data = await _api.deleteInboxItem(id);
      _applyUnread(data);
      items = [for (final it in items) if (it.id != id) it];
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    try {
      final data = await _api.clearInbox();
      _applyUnread(data);
      items = const [];
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  void _applyUnread(Map<String, dynamic> data) {
    final n = data['unread_count'];
    if (n is num) {
      unreadCount = n.toInt();
    } else if (n != null) {
      unreadCount = int.tryParse('$n') ?? unreadCount;
    }
    unawaited(AppBadge.set(unreadCount));
  }

  void resetLocal() {
    items = const [];
    unreadCount = 0;
    nextCursor = null;
    error = null;
    loading = false;
    unawaited(AppBadge.clear());
    notifyListeners();
  }
}
