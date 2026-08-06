import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/api/api_client.dart';

enum AiCommentaryPhase { idle, loading, ready, failed }

/// App-level AI commentary job — `job_id` lives here, not in a dialog.
class AiCommentarySession extends ChangeNotifier with WidgetsBindingObserver {
  AiCommentarySession({
    required ApiClient apiClient,
    this._pollDelayOverride,
  }) : _api = apiClient {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _api;
  final Duration? _pollDelayOverride;

  AiCommentaryPhase phase = AiCommentaryPhase.idle;
  String? symbol;
  String? jobId;
  String? text;
  String? errorMessage;
  String? modelPublic;
  String? metaLine;
  int pollAfterMs = 2000;
  DateTime? startedAt;
  int? lastErrorStatus;

  Map<String, dynamic>? lastPayload;

  int _generation = 0;
  bool _polling = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        phase == AiCommentaryPhase.loading &&
        jobId != null) {
      unawaited(_pollOnce(_generation));
    }
  }

  /// Start or attach to in-flight job for [symbol].
  Future<void> start(String symbol, {int bars = 300}) async {
    final sym = symbol.trim().toUpperCase();
    if (sym.isEmpty) return;

    if (phase == AiCommentaryPhase.loading && this.symbol == sym) {
      // Same symbol already running — keep job_id; no new POST.
      return;
    }

    final gen = ++_generation;
    this.symbol = sym;
    jobId = null;
    text = null;
    errorMessage = null;
    modelPublic = null;
    metaLine = null;
    lastPayload = null;
    lastErrorStatus = null;
    pollAfterMs = 2000;
    startedAt = DateTime.now();
    phase = AiCommentaryPhase.loading;
    notifyListeners();

    try {
      final data = await _api.fetchAiCommentary(symbol: sym, bars: bars);
      if (gen != _generation) return;
      await _handlePostResponse(data, gen);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      lastErrorStatus = e.statusCode;
      _fail(_friendlyApi(e), gen);
    } catch (_) {
      if (gen != _generation) return;
      lastErrorStatus = null;
      _fail('Sunucu ile bağlantı kesildi; tekrar deneyin.', gen);
    }
  }

  Future<void> _handlePostResponse(Map<String, dynamic> data, int gen) async {
    final status = (data['status']?.toString() ?? '').toLowerCase();
    if (status == 'success') {
      final t = data['text']?.toString();
      if (t != null && t.isNotEmpty) {
        _succeed(t, data, gen);
        return;
      }
      _fail(data['message']?.toString() ?? 'Yorum alınamadı.', gen);
      return;
    }
    if (status == 'accepted') {
      final id = data['job_id']?.toString();
      if (id == null || id.isEmpty) {
        _fail('Yorum işi başlatılamadı.', gen);
        return;
      }
      jobId = id;
      final pam = data['poll_after_ms'];
      if (pam is num && pam > 0) pollAfterMs = pam.toInt();
      final mp = data['model_public']?.toString();
      if (mp != null && mp.isNotEmpty) modelPublic = mp;
      notifyListeners();
      unawaited(_pollLoop(gen));
      return;
    }
    if (status == 'busy') {
      _fail(
        data['message']?.toString() ??
            'Model meşgul; biraz sonra tekrar deneyin.',
        gen,
      );
      return;
    }
    _fail(data['message']?.toString() ?? 'Yorum alınamadı.', gen);
  }

  Future<void> _pollLoop(int gen) async {
    if (_polling) return;
    _polling = true;
    try {
      while (gen == _generation && phase == AiCommentaryPhase.loading) {
        final done = await _pollOnce(gen);
        if (done || gen != _generation) return;
        final delay = _pollDelayOverride ??
            Duration(milliseconds: pollAfterMs.clamp(500, 10000));
        await Future<void>.delayed(delay);
      }
    } finally {
      _polling = false;
    }
  }

  /// Returns true when terminal state reached.
  Future<bool> _pollOnce(int gen) async {
    final id = jobId;
    if (id == null || id.isEmpty) return true;
    if (gen != _generation || phase != AiCommentaryPhase.loading) return true;

    try {
      final data = await _api.fetchAiCommentaryJob(id);
      if (gen != _generation) return true;
      final status = (data['status']?.toString() ?? '').toLowerCase();
      if (status == 'queued' || status == 'running') {
        final pam = data['poll_after_ms'];
        if (pam is num && pam > 0) pollAfterMs = pam.toInt();
        return false;
      }
      if (status == 'success') {
        final t = data['text']?.toString();
        if (t != null && t.isNotEmpty) {
          _succeed(t, data, gen);
          return true;
        }
        _fail(data['message']?.toString() ?? 'Yorum alınamadı.', gen);
        return true;
      }
      if (status == 'busy') {
        _fail(
          data['message']?.toString() ??
              'Model meşgul; biraz sonra tekrar deneyin.',
          gen,
        );
        return true;
      }
      if (status == 'failed') {
        _fail(
          data['message']?.toString() ?? 'Yorum üretilemedi; tekrar deneyin.',
          gen,
        );
        return true;
      }
      _fail(data['message']?.toString() ?? 'Yorum alınamadı.', gen);
      return true;
    } on ApiException catch (e) {
      if (gen != _generation) return true;
      lastErrorStatus = e.statusCode;
      if (e.statusCode == 404) {
        _fail('Yorum işi bulunamadı; tekrar deneyin.', gen);
        return true;
      }
      _fail(_friendlyApi(e), gen);
      return true;
    } catch (_) {
      if (gen != _generation) return true;
      // Transient network — keep loading; resume may recover.
      return false;
    }
  }

  void _succeed(String t, Map<String, dynamic> data, int gen) {
    if (gen != _generation) return;
    text = t;
    lastPayload = data;
    final mp = data['model_public']?.toString();
    if (mp != null && mp.isNotEmpty) modelPublic = mp;
    metaLine = buildMetaLine(symbol ?? '', data, modelPublic);
    errorMessage = null;
    phase = AiCommentaryPhase.ready;
    notifyListeners();
  }

  void _fail(String message, int gen) {
    if (gen != _generation) return;
    errorMessage = message;
    text = null;
    phase = AiCommentaryPhase.failed;
    notifyListeners();
  }

  void clear() {
    _generation++;
    phase = AiCommentaryPhase.idle;
    symbol = null;
    jobId = null;
    text = null;
    errorMessage = null;
    modelPublic = null;
    metaLine = null;
    lastPayload = null;
    lastErrorStatus = null;
    startedAt = null;
    notifyListeners();
  }

  /// After UI shows result dialog, return to idle without wiping last text.
  void acknowledge() {
    if (phase == AiCommentaryPhase.ready || phase == AiCommentaryPhase.failed) {
      phase = AiCommentaryPhase.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    super.dispose();
  }
}

/// Fallback brand label when API omits `model_public`.
const aiCommentaryModelFallback = 'lotlotLLMv16';

String buildMetaLine(
  String symbol,
  Map<String, dynamic> data,
  String? modelPublic,
) {
  final model = (modelPublic != null && modelPublic.isNotEmpty)
      ? modelPublic
      : () {
          final m = data['model_public']?.toString();
          return (m != null && m.isNotEmpty) ? m : aiCommentaryModelFallback;
        }();
  final parts = <String>[symbol.toUpperCase(), model];
  final variant = data['prompt_variant']?.toString();
  if (variant != null &&
      variant.isNotEmpty &&
      variant.toLowerCase() != 'short') {
    parts.add(variant);
  }
  if (data['cached'] == true) parts.add('cache');
  final dur = data['duration_s'];
  if (dur is num) parts.add('${dur.toStringAsFixed(2)}s');
  return parts.join(' • ');
}

String _friendlyApi(ApiException e) {
  final code = (e.errorCode ?? '').toLowerCase();
  final status = e.body?['status']?.toString().toLowerCase();
  if (code == 'busy' || status == 'busy' || e.statusCode == 429) {
    if (status == 'busy' || code == 'busy') {
      return e.message.isNotEmpty
          ? e.message
          : 'Model meşgul; biraz sonra tekrar deneyin.';
    }
    return e.message.isNotEmpty
        ? e.message
        : 'Çok sık istek; lütfen biraz bekleyin.';
  }
  if (e.statusCode == 403) {
    return e.message.isNotEmpty ? e.message : 'Bu özellik Pro planda.';
  }
  if (e.statusCode == 502 || e.statusCode == 500) {
    return e.message.isNotEmpty
        ? e.message
        : 'Yorum üretilemedi; tekrar deneyin.';
  }
  return e.message.isNotEmpty ? e.message : 'Yorum alınamadı.';
}
