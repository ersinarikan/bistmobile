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
  bool loadingAuth = false;
  String? error;

  Map<String, dynamic>? valuation;
  Map<String, dynamic>? fundamentals;
  Map<String, dynamic>? corporate;
  List<OhlcvBar> bars = [];
  Map<String, dynamic>? levels;
  Map<String, dynamic>? pattern;
  bool patternPending = false;

  bool get isAuthenticated =>
      _session.status == AuthStatus.authenticated;

  bool get showValuation {
    if (valuation == null) return false;
    final fv = valuation!['fair_value'];
    return fv != null;
  }

  Future<void> load() async {
    loadingPublic = true;
    error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadValuation(),
        _loadFundamentals(),
        _loadCorporate(),
        _loadPublicChart(),
      ]);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingPublic = false;
      notifyListeners();
    }

    if (isAuthenticated) {
      await _loadAuthExtras();
    }
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
    }
  }

  Future<void> _loadFundamentals() async {
    try {
      final data = await _api.fetchPublicFundamentals(symbol);
      final f = data['fundamentals'];
      fundamentals = f is Map ? Map<String, dynamic>.from(f) : null;
    } on ApiException {
      fundamentals = null;
    }
  }

  Future<void> _loadCorporate() async {
    try {
      final data = await _api.fetchPublicCorporate(symbol);
      final c = data['corporate'];
      corporate = c is Map ? Map<String, dynamic>.from(c) : null;
    } on ApiException {
      corporate = null;
    }
  }

  Future<void> _loadPublicChart() async {
    try {
      final data = await _api.fetchPublicChartData(symbol, bars: 180);
      bars = _parseBars(data);
      levels = null;
    } on ApiException {
      bars = [];
    }
  }

  Future<void> _loadAuthExtras() async {
    loadingAuth = true;
    patternPending = false;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchChartData(symbol, bars: 420),
        _api.fetchPatternAnalysis(symbol),
      ]);
      final chart = results[0];
      final authBars = _parseBars(chart);
      if (authBars.isNotEmpty) bars = authBars;
      final lv = chart['levels'];
      levels = lv is Map ? Map<String, dynamic>.from(lv) : null;

      pattern = results[1];
      patternPending = pattern?['status']?.toString() == 'pending';
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        pattern = null;
      } else {
        pattern = null;
        // public chart kalır
      }
    } finally {
      loadingAuth = false;
      notifyListeners();
    }
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
