import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Auth watchlist + predictions (guide §10–§14). Guest çağırmaz.
class WatchlistController extends ChangeNotifier {
  WatchlistController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> predictions = [];
  Map<String, dynamic>? subscription;
  String selectedHorizon = '7d';
  bool loading = false;
  bool mutating = false;
  String? lastError;
  ApiException? lastApiError;

  int? get activeCount {
    final v = subscription?['watchlist_active_count'];
    if (v is num) return v.toInt();
    return items.where((e) => e['active'] != false).length;
  }

  int? get watchlistLimit {
    final v = subscription?['watchlist_limit'];
    return v is num ? v.toInt() : null;
  }

  int? get mutationsRemaining {
    final v = subscription?['monthly_watchlist_mutations_remaining'];
    return v is num ? v.toInt() : null;
  }

  Future<void> refresh() async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final wl = await _api.fetchWatchlist();
      final raw = wl['watchlist'];
      items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      subscription = wl['subscription'] is Map
          ? Map<String, dynamic>.from(wl['subscription'] as Map)
          : null;

      try {
        final pred = await _api.fetchWatchlistPredictions();
        final pRaw = pred['items'];
        predictions = pRaw is List
            ? pRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
      } on ApiException catch (e) {
        // Liste geldiyse predictions hatasını yumuşak tut
        predictions = [];
        if (e.statusCode != 403) {
          lastError = e.message;
        }
      }
    } on ApiException catch (e) {
      items = [];
      predictions = [];
      lastError = _friendly(e);
      if (e.body?['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(e.body!['subscription'] as Map);
      }
    } catch (e) {
      items = [];
      predictions = [];
      lastError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> addSymbol(String symbol) async {
    mutating = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await _api.addWatchlist(symbol: symbol.toUpperCase());
      if (data['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(data['subscription'] as Map);
      }
      await refresh();
      return true;
    } on ApiException catch (e) {
      lastError = _friendly(e);
      if (e.body?['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(e.body!['subscription'] as Map);
      }
      mutating = false;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      mutating = false;
      notifyListeners();
      return false;
    } finally {
      mutating = false;
    }
  }

  Future<bool> removeSymbol(String symbol) async {
    mutating = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await _api.removeWatchlist(symbol);
      if (data['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(data['subscription'] as Map);
      }
      await refresh();
      return true;
    } on ApiException catch (e) {
      lastError = _friendly(e);
      if (e.body?['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(e.body!['subscription'] as Map);
      }
      mutating = false;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      mutating = false;
      notifyListeners();
      return false;
    } finally {
      mutating = false;
    }
  }

  Future<bool> setAlertEnabled(String symbol, bool enabled) async {
    mutating = true;
    lastError = null;
    lastApiError = null;
    notifyListeners();
    try {
      await _api.patchWatchlist(
        symbol.toUpperCase(),
        body: {'alert_enabled': enabled},
      );
      await refresh();
      return true;
    } on ApiException catch (e) {
      lastApiError = e;
      lastError = _friendly(e);
      mutating = false;
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      mutating = false;
      notifyListeners();
      return false;
    } finally {
      mutating = false;
    }
  }

  void clear() {
    items = [];
    predictions = [];
    subscription = null;
    lastError = null;
    lastApiError = null;
    loading = false;
    notifyListeners();
  }

  void setHorizon(String horizon) {
    selectedHorizon = horizon;
    notifyListeners();
  }

  Map<String, dynamic>? signalFor(Map<String, dynamic> pred) {
    final byH = pred['signals_by_horizon'];
    if (byH is! Map) return null;
    final raw = byH[selectedHorizon] ?? byH['7d'] ?? byH['30d'] ?? byH['1d'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _friendly(ApiException e) {
    switch (e.errorCode) {
      case 'email_not_verified':
        return e.message.isNotEmpty
            ? e.message
            : 'E-posta doğrulanmadan liste güncellenemez.';
      case 'watchlist_limit_exceeded':
        return e.message.isNotEmpty
            ? e.message
            : 'İzleme listesi limiti doldu.';
      case 'monthly_watchlist_quota_exceeded':
        return e.message.isNotEmpty
            ? e.message
            : 'Aylık liste değişiklik kotanız doldu.';
      default:
        return e.message;
    }
  }
}
