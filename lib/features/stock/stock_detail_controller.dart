import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../auth/session_controller.dart';

/// OHLCV bar — public chart `ohlcv[]` (time unix).
class OhlcvBar {
  const OhlcvBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  static OhlcvBar? tryParse(Map<String, dynamic> raw) {
    final o = raw['open'];
    final h = raw['high'];
    final l = raw['low'];
    final c = raw['close'];
    final t = raw['time'] ?? raw['date'];
    if (o is! num || h is! num || l is! num || c is! num) return null;
    int time;
    if (t is num) {
      time = t.toInt();
      if (time > 1000000000000) time = time ~/ 1000;
    } else if (t is String) {
      final ms = DateTime.tryParse(t)?.millisecondsSinceEpoch;
      if (ms == null) return null;
      time = ms ~/ 1000;
    } else {
      return null;
    }
    return OhlcvBar(
      time: time,
      open: o.toDouble(),
      high: h.toDouble(),
      low: l.toDouble(),
      close: c.toDouble(),
      volume: raw['volume'] is num ? (raw['volume'] as num).toDouble() : null,
    );
  }
}

/// F3 hisse detay — public parallel + auth pattern/chart (§17, §22).
class StockDetailController extends ChangeNotifier {
  StockDetailController({
    required ApiClient apiClient,
    required this._session,
    required this.symbol,
    this.name,
  }) : _api = apiClient;

  final ApiClient _api;
  final SessionController _session;
  final String symbol;
  final String? name;

  bool loadingPublic = false;
  /// Grafik henüz gelmedi — tam sayfa yerine yalnızca chart alanı.
  bool loadingChart = false;
  bool loadingAuth = false;
  String? error;
  bool _disposed = false;

  Map<String, dynamic>? valuation;
  Map<String, dynamic>? fundamentals;
  Map<String, dynamic>? corporate;
  Map<String, dynamic>? volumeTier;
  List<OhlcvBar> bars = [];
  Map<String, dynamic>? levels;
  Map<String, dynamic>? pattern;
  List<Map<String, dynamic>> forecasts = [];
  bool patternPending = false;

  String? get volatilityRegime {
    final raw = pattern?['volatility_regime']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  bool get isAuthenticated =>
      _session.status == AuthStatus.authenticated;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loadingPublic = true;
    loadingChart = true;
    error = null;
    valuation = null;
    fundamentals = null;
    corporate = null;
    volumeTier = null;
    bars = [];
    levels = null;
    forecasts = [];
    pattern = null;
    patternPending = false;
    _notify();

    // Hepsi paralel; UI chart + valuation geldikçe güncellenir.
    final chartF = _loadPublicChart();
    final valF = _loadValuation();
    final fundF = _loadFundamentals();
    final corpF = _loadCorporate();
    final volF = _loadVolumeTier();

    try {
      await chartF;
    } catch (e) {
      error = e.toString();
    } finally {
      loadingChart = false;
      loadingPublic = false;
      _notify();
    }

    await Future.wait([valF, fundF, corpF, volF]);

    if (isAuthenticated) {
      await _loadAuthExtras();
    } else {
      pattern = null;
      patternPending = false;
      levels = null;
      forecasts = [];
      _notify();
    }
  }

  /// Login sonrası aynı ekranda auth chart + pattern çek.
  Future<void> ensureAuthExtras() async {
    if (!isAuthenticated || _disposed) return;
    await _loadAuthExtras();
  }

  Future<void> _loadValuation() async {
    try {
      final data = await _api.fetchPublicValuation(symbol);
      if (data['status']?.toString() == 'unavailable') {
        valuation = null;
        return;
      }
      final v = data['valuation'];
      valuation = v is Map ? Map<String, dynamic>.from(v) : null;
    } on ApiException {
      valuation = null;
    } finally {
      _notify();
    }
  }

  Future<void> _loadFundamentals() async {
    try {
      final data = await _api.fetchPublicFundamentals(symbol);
      final f = data['fundamentals'];
      fundamentals = f is Map ? Map<String, dynamic>.from(f) : null;
    } on ApiException {
      fundamentals = null;
    } finally {
      _notify();
    }
  }

  Future<void> _loadCorporate() async {
    try {
      final data = await _api.fetchPublicCorporate(symbol);
      final c = data['corporate'];
      corporate = c is Map ? Map<String, dynamic>.from(c) : null;
    } on ApiException {
      corporate = null;
    } finally {
      _notify();
    }
  }

  Future<void> _loadVolumeTier() async {
    try {
      final data = await _api.fetchVolumeTier(symbol);
      volumeTier = Map<String, dynamic>.from(data);
    } on ApiException {
      volumeTier = null;
    } finally {
      _notify();
    }
  }

  Future<void> _loadPublicChart() async {
    try {
      final data = await _api.fetchPublicChartData(symbol, bars: 180);
      bars = _parseBars(data);
      levels = null;
      forecasts = [];
    } on ApiException {
      bars = [];
    } finally {
      _notify();
    }
  }

  Future<void> _loadAuthExtras() async {
    loadingAuth = true;
    patternPending = false;
    _notify();
    try {
      final results = await Future.wait([
        _api.fetchChartData(symbol, bars: 420),
        _api.fetchPatternAnalysis(symbol),
      ]);
      if (_disposed) return;
      final chart = results[0];
      final authBars = _parseBars(chart);
      if (authBars.isNotEmpty) bars = authBars;
      final lv = chart['levels'];
      levels = lv is Map ? Map<String, dynamic>.from(lv) : null;
      forecasts = _parseForecasts(chart);

      pattern = results[1];
      patternPending = pattern?['status']?.toString() == 'pending';
    } on ApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 401) {
        pattern = null;
        levels = null;
        forecasts = [];
      } else {
        pattern = null;
        // public chart kalır
      }
    } finally {
      loadingAuth = false;
      _notify();
    }
  }

  List<Map<String, dynamic>> _parseForecasts(Map<String, dynamic> data) {
    final raw = data['forecasts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<OhlcvBar> _parseBars(Map<String, dynamic> data) {
    final raw = data['ohlcv'] ?? data['data'];
    if (raw is! List) return [];
    final out = <OhlcvBar>[];
    for (final item in raw) {
      if (item is Map) {
        final bar = OhlcvBar.tryParse(Map<String, dynamic>.from(item));
        if (bar != null) out.add(bar);
      }
    }
    return out;
  }
}
