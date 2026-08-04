import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Auth watchlist + predictions (guide §10–§14). Guest çağırmaz.
class WatchlistController extends ChangeNotifier {
  WatchlistController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> predictions = [];
  /// Web kart `#patt-*` — sembol → pattern-analysis payload.
  Map<String, Map<String, dynamic>> patternBySymbol = {};
  Map<String, dynamic>? subscription;
  String selectedHorizon = '7d';
  bool loading = false;
  bool mutating = false;
  String? lastError;
  ApiException? lastApiError;

  /// Son başarılı ekleme liste 0→1 ise true; [takePendingFirstStockGuide] ile alınır.
  bool _pendingFirstStockGuide = false;

  bool takePendingFirstStockGuide() {
    final v = _pendingFirstStockGuide;
    _pendingFirstStockGuide = false;
    return v;
  }

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
        predictions = [];
        if (e.statusCode != 403) {
          lastError = e.message;
        }
      }

      // Kart rozetleri — web gibi pattern-analysis (chunked).
      await _hydratePatterns();
    } on ApiException catch (e) {
      items = [];
      predictions = [];
      patternBySymbol = {};
      lastError = _friendly(e);
      if (e.body?['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(e.body!['subscription'] as Map);
      }
    } catch (e) {
      items = [];
      predictions = [];
      patternBySymbol = {};
      lastError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _hydratePatterns() async {
    final symbols = items
        .map((e) => (e['symbol']?.toString() ?? '').toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (symbols.isEmpty) {
      patternBySymbol = {};
      return;
    }
    final next = <String, Map<String, dynamic>>{};
    const chunk = 4;
    for (var i = 0; i < symbols.length; i += chunk) {
      final slice = symbols.sublist(
        i,
        i + chunk > symbols.length ? symbols.length : i + chunk,
      );
      await Future.wait(slice.map((sym) async {
        try {
          final data = await _api.fetchPatternAnalysis(sym, fast: true);
          next[sym] = data;
        } catch (_) {
          // Rozet yumuşak; listeyi bozma
        }
      }));
    }
    patternBySymbol = next;
  }

  Future<bool> addSymbol(
    String symbol, {
    bool alertEnabled = true,
  }) async {
    mutating = true;
    lastError = null;
    notifyListeners();
    final wasEmpty = items.isEmpty;
    try {
      final data = await _api.addWatchlist(
        symbol: symbol.toUpperCase(),
        alertEnabled: alertEnabled,
      );
      if (data['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(data['subscription'] as Map);
      }
      await refresh();
      _pendingFirstStockGuide = wasEmpty;
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
      // Yerel güncelle (tam refresh yavaş olabilir).
      final key = symbol.toUpperCase();
      for (var i = 0; i < items.length; i++) {
        if ((items[i]['symbol']?.toString() ?? '').toUpperCase() == key) {
          items[i] = {...items[i], 'alert_enabled': enabled};
          break;
        }
      }
      mutating = false;
      notifyListeners();
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
    patternBySymbol = {};
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

  Map<String, dynamic>? predictionForSymbol(String symbol) {
    final key = symbol.toUpperCase();
    for (final p in predictions) {
      if ((p['symbol']?.toString() ?? '').toUpperCase() == key) {
        return p;
      }
    }
    return null;
  }

  Map<String, dynamic>? patternForSymbol(String symbol) {
    return patternBySymbol[symbol.toUpperCase()];
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
