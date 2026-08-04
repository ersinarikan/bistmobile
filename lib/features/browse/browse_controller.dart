import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Public keşif: arama + BIST screener (guide §17 — Bearer yok).
class BrowseController extends ChangeNotifier {
  BrowseController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  Timer? _debounce;

  String indexKey = 'bist-30';
  String? defaultHorizon = '30d';
  List<Map<String, dynamic>> screenerRows = [];
  List<Map<String, dynamic>> searchResults = [];
  String searchQuery = '';
  bool loadingScreener = false;
  bool loadingSearch = false;
  String? error;

  bool get isSearching => searchQuery.trim().length >= 2;

  Future<void> loadScreener({String? index}) async {
    if (index != null) indexKey = index;
    loadingScreener = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.fetchIndexScreener(indexKey);
      if (data['status']?.toString() == 'pending') {
        screenerRows = [];
        defaultHorizon = data['default_horizon']?.toString() ?? '30d';
      } else {
        defaultHorizon = data['default_horizon']?.toString() ?? '30d';
        final raw = data['rows'];
        screenerRows = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        final horizon = defaultHorizon ?? '30d';
        screenerRows.sort((a, b) {
          final sa = _score(a, horizon);
          final sb = _score(b, horizon);
          return sb.compareTo(sa);
        });
      }
    } on ApiException catch (e) {
      error = e.message;
      screenerRows = [];
    } catch (e) {
      error = e.toString();
      screenerRows = [];
    } finally {
      loadingScreener = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String value) {
    searchQuery = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      searchResults = [];
      loadingSearch = false;
      notifyListeners();
      return;
    }
    loadingSearch = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String q) async {
    try {
      final data = await _api.searchStocks(q);
      if (searchQuery.trim() != q) return;
      final raw = data['stocks'];
      searchResults = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      error = null;
    } on ApiException catch (e) {
      if (searchQuery.trim() != q) return;
      error = e.message;
      searchResults = [];
    } catch (e) {
      if (searchQuery.trim() != q) return;
      error = e.toString();
      searchResults = [];
    } finally {
      if (searchQuery.trim() == q) {
        loadingSearch = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() async {
    if (isSearching) {
      loadingSearch = true;
      error = null;
      notifyListeners();
      await _runSearch(searchQuery.trim());
    } else {
      await loadScreener();
    }
  }

  double _score(Map<String, dynamic> row, String horizon) {
    final scores = row['lotlot_scores'];
    if (scores is Map && scores[horizon] != null) {
      return (scores[horizon] as num).toDouble();
    }
    return 0;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
