import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/session_controller.dart';
import '../../stock/stock_detail_controller.dart';
import '../../stock/widgets/market_meta_card.dart';
import '../../stock/widgets/pattern_section.dart';
import 'watchlist_big_chart_screen.dart';

/// Web `#detailModal` parity — liste üstünde sheet.
Future<void> showWatchlistDetailSheet(
  BuildContext context, {
  required String symbol,
  String? name,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LotlotColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LotlotColors.radiusLg),
      ),
    ),
    builder: (ctx) {
      return ChangeNotifierProvider(
        create: (_) => StockDetailController(
          apiClient: context.read<ApiClient>(),
          session: context.read<SessionController>(),
          symbol: symbol.toUpperCase(),
          name: name,
        )..load(),
        child: _WatchlistDetailSheetBody(symbol: symbol, name: name),
      );
    },
  );
}

class _WatchlistDetailSheetBody extends StatelessWidget {
  const _WatchlistDetailSheetBody({required this.symbol, this.name});

  final String symbol;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StockDetailController>();
    final session = context.watch<SessionController>();
    final auth = session.status == AuthStatus.authenticated;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: LotlotColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$symbol Detay',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (ctrl.loadingPublic && ctrl.bars.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: LotlotColors.accent),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (ctrl.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ctrl.error!,
                        style: const TextStyle(color: LotlotColors.danger),
                      ),
                    ),
                  _SparkPreview(
                    bars: ctrl.bars,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WatchlistBigChartScreen(
                            symbol: symbol,
                            name: name,
                            controller: ctrl,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  MarketMetaCard(
                    volumeTier: ctrl.volumeTier,
                    volatilityRegime: ctrl.volatilityRegime,
                  ),
                  const SizedBox(height: 8),
                  PatternSection(
                    isAuthenticated: auth,
                    loading: ctrl.loadingAuth,
                    pending: ctrl.patternPending,
                    pattern: ctrl.pattern,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yatırım tavsiyesi değildir. Veri analizidir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SparkPreview extends StatelessWidget {
  const _SparkPreview({required this.bars, required this.onOpen});

  final List<OhlcvBar> bars;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LotlotColors.surface,
      borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      child: InkWell(
        onTap: bars.isEmpty ? null : onOpen,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
            border: Border.all(color: LotlotColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: bars.isEmpty
                    ? const Center(
                        child: Text(
                          'Grafik yükleniyor…',
                          style: TextStyle(color: LotlotColors.textSecondary),
                        ),
                      )
                    : CustomPaint(
                        painter: _SparkPainter(bars: bars),
                        child: const SizedBox.expand(),
                      ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.open_in_full, size: 16, color: LotlotColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'Büyük mum grafiği — tıklayın',
                    style: TextStyle(
                      color: LotlotColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.bars});

  final List<OhlcvBar> bars;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final take = math.min(60, bars.length);
    final slice = bars.sublist(bars.length - take);
    var minY = slice.map((b) => b.low).reduce(math.min);
    var maxY = slice.map((b) => b.high).reduce(math.max);
    if (maxY <= minY) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    final path = Path();
    for (var i = 0; i < slice.length; i++) {
      final x = slice.length == 1
          ? size.width / 2
          : i * size.width / (slice.length - 1);
      final y = size.height *
          (1 - ((slice[i].close - minY) / (maxY - minY)).clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = LotlotColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.bars != bars;
}
