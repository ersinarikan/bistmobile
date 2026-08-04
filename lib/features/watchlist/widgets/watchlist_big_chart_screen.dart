import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import '../../stock/stock_detail_controller.dart';
import '../../stock/widgets/simple_candle_chart.dart';

/// Web `#chartModal` — Öngörü tick + AI footer.
class WatchlistBigChartScreen extends StatefulWidget {
  const WatchlistBigChartScreen({
    super.key,
    required this.symbol,
    this.name,
    required this.controller,
  });

  final String symbol;
  final String? name;
  final StockDetailController controller;

  @override
  State<WatchlistBigChartScreen> createState() =>
      _WatchlistBigChartScreenState();
}

class _WatchlistBigChartScreenState extends State<WatchlistBigChartScreen> {
  bool _showForecast = false;
  bool _aiLoading = false;
  String? _aiText;
  String? _aiError;

  List<({int start, int end, bool bullish})> get _ranges =>
      _patternRangesFrom(widget.controller.pattern);

  Future<void> _toggleForecast(bool? value) async {
    final want = value == true;
    if (!want) {
      setState(() => _showForecast = false);
      return;
    }
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(popOnSuccess: true),
        ),
      );
      return;
    }
    if (!session.isPro) {
      await showSoftGateSheet(context, kind: SoftGateKind.pro);
      return;
    }
    setState(() => _showForecast = true);
  }

  Future<void> _runAi() async {
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(popOnSuccess: true),
        ),
      );
      return;
    }
    if (!session.isPro) {
      await showSoftGateSheet(context, kind: SoftGateKind.pro);
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final res = await context.read<ApiClient>().fetchAiCommentary(
            symbol: widget.symbol,
          );
      if (!mounted) return;
      final text = res['text']?.toString();
      if (res['status']?.toString() == 'success' &&
          text != null &&
          text.isNotEmpty) {
        setState(() {
          _aiText = text;
          _aiLoading = false;
        });
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: LotlotColors.surface,
            title: const Text('lotlot.net Yorumu'),
            content: SingleChildScrollView(child: Text(text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _aiError = res['message']?.toString() ?? 'Yorum alınamadı';
          _aiLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && tryShowSoftGateForApiError(context, e)) {
        setState(() => _aiLoading = false);
        return;
      }
      setState(() {
        _aiLoading = false;
        _aiError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiError = 'Yorum alınamadı; tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.symbol),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (ctrl.loadingAuth && ctrl.bars.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: LotlotColors.accent,
                          ),
                        ),
                      )
                    else
                      SimpleCandleChart(
                        bars: ctrl.bars,
                        levels: ctrl.levels,
                        forecasts:
                            _showForecast ? ctrl.forecasts : const [],
                        patternRanges: _ranges,
                        forceDetailed: _showForecast,
                        showForecastToggle: true,
                        forecastEnabled: _showForecast,
                        onForecastChanged: _toggleForecast,
                      ),
                    if (_aiError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _aiError!,
                          style: const TextStyle(color: LotlotColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _aiLoading ? null : _runAi,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology, size: 20),
                      label: Text(
                        _aiText == null
                            ? 'lotlot.net Yorumu'
                            : 'Yorumu yenile',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<({int start, int end, bool bullish})> _patternRangesFrom(
  Map<String, dynamic>? pattern,
) {
  final raw = pattern?['patterns'];
  if (raw is! List) return const [];
  final out = <({int start, int end, bool bullish})>[];
  const skip = {'ML_PREDICTOR', 'ENHANCED_ML', 'FINGPT'};
  for (final item in raw) {
    if (item is! Map) continue;
    final src = item['source']?.toString() ?? '';
    if (skip.contains(src)) continue;
    final range = item['range'];
    if (range is! Map) continue;
    final s = range['start_index'];
    final e = range['end_index'];
    if (s is! num || e is! num) continue;
    final signal = (item['signal'] ?? '').toString().toLowerCase();
    final bullish =
        signal.contains('bull') || signal == 'buy' || signal == 'al';
    out.add((start: s.round(), end: e.round(), bullish: bullish));
  }
  return out;
}
