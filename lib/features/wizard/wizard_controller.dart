import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

/// Premium Hisse Sihirbazı — POST /api/watchlist/wizard/recommendations.
class WizardController extends ChangeNotifier {
  WizardController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static const horizonsAll = ['1d', '3d', '7d', '14d', '30d'];
  static const signalsAll = ['AL', 'SAT', 'TUT'];
  static const universes = ['all', 'bist30', 'bist100'];

  /// Web parity defaults: 7d, AL, all.
  final Set<String> selectedHorizons = {'7d'};
  final Set<String> selectedSignals = {'AL'};
  String universe = 'all';
  int limit = 5;
  int daysBack = 7;

  bool loading = false;
  String? lastError;
  ApiException? lastApiError;
  List<Map<String, dynamic>> results = [];
  int count = 0;
  Map<String, dynamic>? requested;

  void toggleHorizon(String h) {
    if (selectedHorizons.contains(h)) {
      if (selectedHorizons.length == 1) return;
      selectedHorizons.remove(h);
    } else {
      selectedHorizons.add(h);
    }
    notifyListeners();
  }

  void toggleSignal(String s) {
    if (selectedSignals.contains(s)) {
      if (selectedSignals.length == 1) return;
      selectedSignals.remove(s);
    } else {
      selectedSignals.add(s);
    }
    notifyListeners();
  }

  void setUniverse(String u) {
    universe = u;
    notifyListeners();
  }

  void setLimit(int v) {
    limit = v.clamp(1, 10);
    notifyListeners();
  }

  void setDaysBack(int v) {
    daysBack = v.clamp(1, 30);
    notifyListeners();
  }

  Future<bool> run() async {
    loading = true;
    lastError = null;
    lastApiError = null;
    notifyListeners();
    try {
      final res = await _api.fetchWizardRecommendations(
        horizons: selectedHorizons.toList(),
        signalTypes: selectedSignals.toList(),
        universe: universe,
        limit: limit,
        daysBack: daysBack,
      );
      final raw = res['results'];
      results = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      count = res['count'] is num
          ? (res['count'] as num).toInt()
          : results.length;
      requested = res['requested'] is Map
          ? Map<String, dynamic>.from(res['requested'] as Map)
          : null;
      return true;
    } on ApiException catch (e) {
      lastApiError = e;
      lastError = _friendly(e);
      results = [];
      count = 0;
      return false;
    } catch (e) {
      lastError = e.toString();
      results = [];
      count = 0;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String _friendly(ApiException e) {
    if (e.errorCode == 'invalid_selection') {
      final details = e.body?['details'];
      if (details is List && details.isNotEmpty) {
        return details.map((e) => e.toString()).join('\n');
      }
      return 'Geçersiz seçim; horizon ve sinyal seçin.';
    }
    return e.message;
  }
}
