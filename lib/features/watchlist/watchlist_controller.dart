import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Auth watchlist + predictions (guide §10–§14). Guest çağırmaz.
///
/// Progressive enrich: §10 liste erken boyanır; §14 + pattern arka planda.
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
  /// §14 predictions isteği sürüyor.
  bool enrichingPredictions = false;
  /// Pattern-analysis chunk’ları sürüyor.
  bool enrichingPatterns = false;
  bool mutating = false;
  String? lastError;
  ApiException? lastApiError;

  /// Ardışık refresh yarışında eski enrich’i düşürmek için.
  int _refreshGeneration = 0;

  /// Son başarılı ekleme liste 0→1 ise true; [takePendingFirstStockGuide] ile alınır.
  bool _pendingFirstStockGuide = false;

  bool get enriching => enrichingPredictions || enrichingPatterns;

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

  int? get inactiveCount {
    final v = subscription?['watchlist_inactive_count'];
    if (v is num) return v.toInt();
    return items.where((e) => e['active'] == false).length;
  }

  int? get watchlistLimit {
    final v = subscription?['watchlist_limit'];
    return v is num ? v.toInt() : null;
  }

  int? get mutationsRemaining {
    final v = subscription?['monthly_watchlist_mutations_remaining'];
    return v is num ? v.toInt() : null;
  }

  int? get mutationsUsed {
    final v = subscription?['monthly_watchlist_mutations_used'];
    return v is num ? v.toInt() : null;
  }

  /// Ücretsize düşünce önceki plandan biriken mutation — 36/10 gibi taşma gösterme.
  bool get mutationsCarryoverExhausted {
    final rem = mutationsRemaining;
    final used = mutationsUsed;
    if (rem == null || used == null || rem > 0) return false;
    // remaining 0 ve used, ücretsiz aylık haktan (10) veya watchlist limitinden belirgin fazla.
    final cap = watchlistLimit ?? 10;
    return used > cap;
  }

  static bool isItemActive(Map<String, dynamic> item) => item['active'] != false;

  Future<void> refresh() async {
    final gen = ++_refreshGeneration;
    final hadItems = items.isNotEmpty;
    // Stale kartlar varsa tam ekran spinner yok; pull/login’de liste kalsın.
    loading = !hadItems;
    lastError = null;
    enrichingPredictions = false;
    enrichingPatterns = false;
    notifyListeners();
    try {
      final wl = await _api.fetchWatchlist();
      if (gen != _refreshGeneration) return;

      final raw = wl['watchlist'];
      final parsed = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      // Aktifler üstte; pasif (tier_limit) altta kısa satır.
      parsed.sort((a, b) {
        final aa = isItemActive(a) ? 0 : 1;
        final bb = isItemActive(b) ? 0 : 1;
        return aa.compareTo(bb);
      });
      items = parsed;
      subscription = wl['subscription'] is Map
          ? Map<String, dynamic>.from(wl['subscription'] as Map)
          : null;
      // Sembol seti değiştiyse eski pred/pattern’ı temizle (yanlış kart sinyali yok).
      // Pred/pattern yalnız aktif semboller — pasif kartta canlı sinyal yok.
      final activeKeys = items
          .where(isItemActive)
          .map((e) => (e['symbol']?.toString() ?? '').toUpperCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      predictions = predictions
          .where(
            (e) => activeKeys.contains(
              (e['symbol']?.toString() ?? '').toUpperCase(),
            ),
          )
          .toList();
      patternBySymbol = Map<String, Map<String, dynamic>>.fromEntries(
        patternBySymbol.entries.where((e) => activeKeys.contains(e.key)),
      );
      loading = false;
      notifyListeners();

      enrichingPredictions = true;
      notifyListeners();
      try {
        final pred = await _api.fetchWatchlistPredictions();
        if (gen != _refreshGeneration) return;
        final pRaw = pred['items'];
        predictions = pRaw is List
            ? pRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
      } on ApiException catch (e) {
        if (gen != _refreshGeneration) return;
        // Predictions ikincil; 429/403 listeyi boşaltmaz (§14 soft).
        predictions = [];
        if (e.statusCode != 403) {
          lastError = _friendly(e);
        }
      } finally {
        if (gen == _refreshGeneration) {
          enrichingPredictions = false;
          notifyListeners();
        }
      }

      if (gen != _refreshGeneration) return;
      enrichingPatterns = true;
      notifyListeners();
      await _hydratePatterns(gen);
    } on ApiException catch (e) {
      if (gen != _refreshGeneration) return;
      // Geçici limit/5xx: mevcut kartları silme (boş liste + eski kota yanılsaması).
      if (e.statusCode == 429 || e.statusCode >= 500) {
        lastError = _friendly(e);
      } else {
        items = [];
        predictions = [];
        patternBySymbol = {};
        lastError = _friendly(e);
        if (e.body?['subscription'] is Map) {
          subscription =
              Map<String, dynamic>.from(e.body!['subscription'] as Map);
        }
      }
    } catch (e) {
      if (gen != _refreshGeneration) return;
      lastError = e.toString();
    } finally {
      if (gen == _refreshGeneration) {
        loading = false;
        enrichingPredictions = false;
        enrichingPatterns = false;
        notifyListeners();
      }
    }
  }

  Future<void> _hydratePatterns(int gen) async {
    // Pasif (tier_limit) için pattern çekme — kota/iş yükü + yanlış “canlı” izlenim.
    final symbols = items
        .where(isItemActive)
        .map((e) => (e['symbol']?.toString() ?? '').toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (symbols.isEmpty) {
      if (gen != _refreshGeneration) return;
      patternBySymbol = {};
      enrichingPatterns = false;
      notifyListeners();
      return;
    }
    final next = <String, Map<String, dynamic>>{};
    const chunk = 4;
    for (var i = 0; i < symbols.length; i += chunk) {
      if (gen != _refreshGeneration) return;
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
      if (gen != _refreshGeneration) return;
      // Chunk sonrası merge — progressive rozet boyama.
      patternBySymbol = {...patternBySymbol, ...next};
      notifyListeners();
    }
    if (gen != _refreshGeneration) return;
    patternBySymbol = next;
    enrichingPatterns = false;
    notifyListeners();
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
    if (mutating) return false;
    mutating = true;
    lastError = null;
    notifyListeners();
    final key = symbol.toUpperCase();
    try {
      // DELETE §13 — başarıdan sonra yerel çıkar; refresh 429 olsa da kart kalmaz.
      final data = await _api.removeWatchlist(key);
      if (data['subscription'] is Map) {
        subscription = Map<String, dynamic>.from(data['subscription'] as Map);
      }
      items = items
          .where((e) => (e['symbol']?.toString() ?? '').toUpperCase() != key)
          .toList();
      predictions = predictions
          .where((e) => (e['symbol']?.toString() ?? '').toUpperCase() != key)
          .toList();
      patternBySymbol = Map<String, Map<String, dynamic>>.from(patternBySymbol)
        ..remove(key);
      // Enrich beklerken sil butonu kilitli kalmasın.
      mutating = false;
      notifyListeners();
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
    _refreshGeneration++;
    items = [];
    predictions = [];
    patternBySymbol = {};
    subscription = null;
    lastError = null;
    lastApiError = null;
    loading = false;
    enrichingPredictions = false;
    enrichingPatterns = false;
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
      case 'rate_limited':
        return e.message.isNotEmpty
            ? e.message
            : 'Çok hızlı istek gönderildi. Biraz bekleyip tekrar deneyin.';
      default:
        if (e.statusCode == 429) {
          return 'Çok hızlı istek gönderildi. Biraz bekleyip tekrar deneyin.';
        }
        return e.message;
    }
  }
}
