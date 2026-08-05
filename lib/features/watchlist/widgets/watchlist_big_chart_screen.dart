import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../chart_alerts/create_chart_alert_sheet.dart';
import '../../pro/soft_gate_sheet.dart';
import '../../stock/stock_detail_controller.dart';
import '../../stock/widgets/ai_commentary_flow.dart';
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
  bool _aiDoneOnce = false;

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

  Future<void> _onAlarm() async {
    final bars = widget.controller.bars;
    final lastClose = bars.isNotEmpty ? bars.last.close : null;
    final ok = await showCreateChartAlertSheet(
      context,
      initialSymbol: widget.symbol,
      initialSource: 'price',
      initialValue: lastClose,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uyarı eklendi')),
    );
  }

  Future<void> _runAi() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    await runAiCommentaryFlow(context, symbol: widget.symbol);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiDoneOnce = true;
    });
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
            actions: [
              IconButton(
                tooltip: 'Grafik uyarısı',
                onPressed: _onAlarm,
                icon: const Icon(Icons.notification_add_outlined),
              ),
            ],
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
                        pattern: ctrl.pattern,
                        showForecastToggle: true,
                        forecastEnabled: _showForecast,
                        onForecastChanged: _toggleForecast,
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
                      icon: const Icon(Icons.psychology, size: 20),
                      label: Text(
                        _aiDoneOnce
                            ? 'Yorumu yenile'
                            : 'lotlot.net Yorumu',
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
