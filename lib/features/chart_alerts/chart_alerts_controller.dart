import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Chart alerts — Pro+ (§18.3).
class ChartAlertsController extends ChangeNotifier {
  ChartAlertsController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<Map<String, dynamic>> alerts = [];
  Map<String, dynamic>? limits;
  bool loading = false;
  bool mutating = false;
  String? lastError;
  ApiException? lastApiError;

  int? get used {
    final v = limits?['used'] ??
        limits?['active'] ??
        limits?['active_count'] ??
        limits?['count'];
    return v is num ? v.toInt() : null;
  }

  int? get limit {
    final v = limits?['limit'] ?? limits?['chart_alert_limit'];
    return v is num ? v.toInt() : null;
  }

  /// `channels_allowed` yoksa sunucu karar versin (true).
  bool get channelsPushAllowed {
    final ch = limits?['channels_allowed'];
    if (ch is! Map) return true;
    return ch['push'] == true;
  }

  Future<void> refresh() async {
    loading = true;
    lastError = null;
    lastApiError = null;
    notifyListeners();
    try {
      final lim = await _api.fetchChartAlertLimits();
      final nested = lim['limits'];
      limits = nested is Map
          ? Map<String, dynamic>.from(nested)
          : Map<String, dynamic>.from(lim);
      final list = await _api.fetchChartAlerts();
      final raw = list['alerts'] ?? list['items'] ?? list['data'];
      alerts = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
    } on ApiException catch (e) {
      lastApiError = e;
      lastError = _friendly(e);
      alerts = [];
      limits = null;
    } catch (e) {
      lastError = e.toString();
      alerts = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String symbol,
    required String source,
    required String operator_,
    required num value,
    required bool notifyEmail,
    required bool notifyPush,
    String frequency = 'once',
    String? description,
  }) async {
    mutating = true;
    lastError = null;
    lastApiError = null;
    notifyListeners();
    try {
      await _api.createChartAlert({
        'symbol': symbol.toUpperCase(),
        'conditions': [
          {'source': source, 'operator': operator_, 'value': value},
        ],
        'combine': 'or',
        'frequency': frequency,
        if (description != null && description.isNotEmpty)
          'description': description,
        'notify_email': notifyEmail,
        'notify_push': notifyPush,
      });
      await refresh();
      return true;
    } on ApiException catch (e) {
      lastApiError = e;
      lastError = _friendly(e);
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  Future<bool> remove(String id) async {
    mutating = true;
    lastError = null;
    notifyListeners();
    try {
      await _api.deleteChartAlert(id);
      await refresh();
      return true;
    } on ApiException catch (e) {
      lastApiError = e;
      lastError = _friendly(e);
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  String _friendly(ApiException e) {
    switch (e.errorCode) {
      case 'chart_alert_limit_reached':
        return e.message.isNotEmpty
            ? e.message
            : 'Grafik uyarı kotası doldu.';
      case 'chart_alerts_not_available':
        return 'Grafik uyarıları bu planda kullanılamıyor.';
      case 'push_disabled':
        return 'Hesapta push kapalı. Hesap ayarlarından açın.';
      default:
        return e.message;
    }
  }
}
