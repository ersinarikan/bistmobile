import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Public `GET /api/stocks` kataloğu + yerel arama / sektör / endeks filtresi.
class StocksCatalogController extends ChangeNotifier {
  StocksCatalogController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<Map<String, dynamic>> _all = [];
  Set<String> _bist30 = {};
  Set<String> _bist100 = {};

  String query = '';
  String? sector;
  /// `null` | `bist-30` | `bist-100`
  String? indexFilter;

  bool loading = false;
  bool loadingIndexes = false;
  String? error;

  List<String> get sectors {
    final counts = <String, int>{};
    for (final s in _all) {
      final sec = s['sector']?.toString().trim();
      if (sec == null || sec.isEmpty || sec == 'N/A') continue;
      counts[sec] = (counts[sec] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys;
  }

  int get totalCount => _all.length;

  int get bist30Count => _bist30.length;
  int get bist100Count => _bist100.length;

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    Iterable<Map<String, dynamic>> rows = _all;

    if (indexFilter == 'bist-30') {
      rows = rows.where((s) => _bist30.contains(_sym(s)));
    } else if (indexFilter == 'bist-100') {
      rows = rows.where((s) => _bist100.contains(_sym(s)));
    }

    if (sector != null && sector!.isNotEmpty) {
      rows = rows.where((s) => s['sector']?.toString() == sector);
    }

    if (q.isNotEmpty) {
      rows = rows.where((s) => _matches(s, q));
    }

    final list = rows.toList();
    list.sort((a, b) => _sym(a).compareTo(_sym(b)));
    return list;
  }

  Future<void> load() async {
    if (_all.isNotEmpty && error == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.fetchStocksCatalog();
      final raw = data['stocks'];
      _all = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      _all = [];
    } catch (e) {
      error = e.toString();
      _all = [];
    } finally {
      loading = false;
      notifyListeners();
    }
    // Endeks sembolleri arka planda (filtre chip’leri)
    unawaited(_ensureIndexes());
  }

  Future<void> reload() async {
    _all = [];
    await load();
  }

  Future<void> _ensureIndexes() async {
    if (_bist30.isNotEmpty && _bist100.isNotEmpty) return;
    loadingIndexes = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchIndexScreener('bist-30'),
        _api.fetchIndexScreener('bist-100'),
      ]);
      _bist30 = _symbolsFromScreener(results[0]);
      _bist100 = _symbolsFromScreener(results[1]);
    } catch (_) {
      // Chip filtreleri yoksa katalog yine çalışır
    } finally {
      loadingIndexes = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setSector(String? value) {
    sector = (value == null || value.isEmpty) ? null : value;
    notifyListeners();
  }

  void toggleIndex(String key) {
    indexFilter = indexFilter == key ? null : key;
    notifyListeners();
  }

  static String _sym(Map<String, dynamic> s) =>
      (s['symbol']?.toString() ?? '').toUpperCase();

  static bool _matches(Map<String, dynamic> s, String q) {
    final symbol = _sym(s).toLowerCase();
    if (symbol.contains(q)) return true;
    final name = s['name']?.toString().toLowerCase() ?? '';
    if (name.contains(q)) return true;
    final aliases = s['aliases'];
    if (aliases is List) {
      for (final a in aliases) {
        if (a.toString().toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }

  static Set<String> _symbolsFromScreener(Map<String, dynamic> data) {
    final raw = data['rows'];
    if (raw is! List) return {};
    return {
      for (final row in raw)
        if (row is Map && row['symbol'] != null)
          row['symbol'].toString().toUpperCase(),
    };
  }
}
