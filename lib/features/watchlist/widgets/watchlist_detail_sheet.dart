import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import '../../stock/stock_detail_controller.dart';
import '../../stock/widgets/fundamentals_card.dart';
import '../../stock/widgets/market_meta_card.dart';
import '../../stock/widgets/pattern_section.dart';
import '../../stock/widgets/valuation_card.dart';
import '../watchlist_controller.dart';
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

class _WatchlistDetailSheetBody extends StatefulWidget {
  const _WatchlistDetailSheetBody({required this.symbol, this.name});

  final String symbol;
  final String? name;

  @override
  State<_WatchlistDetailSheetBody> createState() =>
      _WatchlistDetailSheetBodyState();
}

class _WatchlistDetailSheetBodyState extends State<_WatchlistDetailSheetBody> {
  int? _selectedFormationNormIdx;

  String get symbol => widget.symbol;
  String? get name => widget.name;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StockDetailController>();
    final session = context.watch<SessionController>();
    final wl = context.watch<WatchlistController>();
    final auth = session.status == AuthStatus.authenticated;
    final showFormations = session.isPro || session.isPremium;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    Map<String, dynamic>? item;
    final key = symbol.toUpperCase();
    for (final e in wl.items) {
      if ((e['symbol']?.toString() ?? '').toUpperCase() == key) {
        item = e;
        break;
      }
    }
    final alertOn = item?['alert_enabled'] == true;

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
          if (ctrl.loadingPublic &&
              ctrl.bars.isEmpty &&
              ctrl.valuation == null &&
              ctrl.fundamentals == null)
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
                  if (ctrl.loadingPublic)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(
                        color: LotlotColors.accent,
                        minHeight: 2,
                      ),
                    ),
                  if (ctrl.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ctrl.error!,
                        style: const TextStyle(color: LotlotColors.danger),
                      ),
                    ),
                  if (auth)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sinyal bildirimi'),
                      subtitle: Text(
                        session.isPremium
                            ? 'Kartta Bildirim: ${alertOn ? 'Açık' : 'Kapalı'}'
                            : 'Açmak için Premium gerekir',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: alertOn,
                      onChanged: wl.mutating
                          ? null
                          : (v) => _onAlertChanged(context, v),
                      activeThumbColor: LotlotColors.onAccent,
                      activeTrackColor: LotlotColors.accent,
                    ),
                  _SparkPreview(
                    bars: ctrl.bars,
                    pattern: ctrl.pattern,
                    showFormations: showFormations,
                    selectedNormIdx: _selectedFormationNormIdx,
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
                  // Pattern uzun; adil/temel spark altında kalsın (Keşfet detay gibi)
                  ValuationCard(valuation: ctrl.valuation),
                  FundamentalsCard(fundamentals: ctrl.fundamentals),
                  PatternSection(
                    isAuthenticated: auth,
                    loading: ctrl.loadingAuth,
                    pending: ctrl.patternPending,
                    pattern: ctrl.pattern,
                    formationDisplayCount: estimateSparkDisplayCount(
                      ctrl.pattern,
                      ctrl.bars.length,
                    ),
                    selectedFormationNormIdx: _selectedFormationNormIdx,
                    onFormationTap: (normIdx) {
                      setState(() => _selectedFormationNormIdx = normIdx);
                    },
                  ),
                  MarketMetaCard(
                    volumeTier: ctrl.volumeTier,
                    volatilityRegime: ctrl.volatilityRegime,
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

  Future<void> _onAlertChanged(BuildContext context, bool value) async {
    final session = context.read<SessionController>();
    final wl = context.read<WatchlistController>();
    if (value && !session.isPremium) {
      await showSoftGateSheet(context, kind: SoftGateKind.premium);
      return;
    }
    final ok = await wl.setAlertEnabled(symbol, value);
    if (!context.mounted) return;
    if (!ok && wl.lastError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(wl.lastError!)));
    } else if (ok && value && !session.pushNotificationsOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sinyal uyarısı açıldı; cihaz push için '
            'Hesap → Push bildirimlerini açın.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

class _SparkPreview extends StatelessWidget {
  const _SparkPreview({
    required this.bars,
    required this.onOpen,
    this.pattern,
    this.showFormations = false,
    this.selectedNormIdx,
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? pattern;
  final bool showFormations;
  final int? selectedNormIdx;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final displayCount = estimateSparkDisplayCount(pattern, bars.length);
    final ranges = showFormations
        ? normalizeSparkFormationRanges(pattern, displayCount)
        : const <SparkFormationRange>[];
    final slice = displayCount > 0
        ? bars.sublist(bars.length - displayCount)
        : const <OhlcvBar>[];
    final minPrice = slice.isEmpty
        ? null
        : slice.map((bar) => bar.low).reduce(math.min);
    final maxPrice = slice.isEmpty
        ? null
        : slice.map((bar) => bar.high).reduce(math.max);

    return Material(
      color: LotlotColors.surface,
      borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: bars.isEmpty ? null : onOpen,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 200,
                  child: bars.isEmpty
                      ? const Center(
                          child: Text(
                            'Grafik yükleniyor…',
                            style: TextStyle(color: LotlotColors.textSecondary),
                          ),
                        )
                      : CustomPaint(
                          painter: _SparkPainter(
                            bars: bars,
                            displayCount: displayCount,
                            formationRanges: ranges,
                            selectedNormIdx: selectedNormIdx,
                          ),
                          child: const SizedBox.expand(),
                        ),
                ),
              ),
            ),
            if (slice.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Bar: ${slice.length} · En düşük '
                    '₺${minPrice!.toStringAsFixed(2)} · En yüksek '
                    '₺${maxPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (ranges.isNotEmpty)
                    Text(
                      'Formasyon: ${ranges.length}',
                      style: const TextStyle(
                        color: LotlotColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.open_in_full,
                  size: 16,
                  color: LotlotColors.accent,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Büyük mum grafiği — tıklayın',
                    style: TextStyle(
                      color: LotlotColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.bars,
    required this.displayCount,
    this.formationRanges = const [],
    this.selectedNormIdx,
  });

  final List<OhlcvBar> bars;
  final int displayCount;
  final List<SparkFormationRange> formationRanges;
  final int? selectedNormIdx;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final take = math.min(displayCount, bars.length);
    if (take <= 0) return;
    final slice = bars.sublist(bars.length - take);
    final n = slice.length;
    var minY = slice.map((b) => b.low).reduce(math.min);
    var maxY = slice.map((b) => b.high).reduce(math.max);
    if (maxY <= minY) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    const labelWidth = 52.0;
    final chartWidth = math.max(0.0, size.width - labelWidth);
    double xAt(int i) => n == 1 ? chartWidth / 2 : i * chartWidth / (n - 1);
    double yAt(double close) =>
        size.height * (1 - ((close - minY) / (maxY - minY)).clamp(0.0, 1.0));

    // Fill under line
    final fillPath = Path()..moveTo(xAt(0), size.height);
    for (var i = 0; i < n; i++) {
      fillPath.lineTo(xAt(i), yAt(slice[i].close));
    }
    fillPath
      ..lineTo(xAt(n - 1), size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
          LotlotColors.accent.withValues(alpha: 0.22),
          LotlotColors.accent.withValues(alpha: 0.02),
        ]),
    );

    // Base line (accent), segment-colored on formations like web Chart.js
    for (var i = 0; i < n - 1; i++) {
      final matchingRanges = formationRanges
          .where((range) => i >= range.start && i <= range.end)
          .toList();
      final selected =
          selectedNormIdx != null &&
          matchingRanges.any((range) => range.normIdx == selectedNormIdx);
      final inFormation = matchingRanges.isNotEmpty;
      final dimmed = selectedNormIdx != null && inFormation && !selected;
      final paint = Paint()
        ..color = selected
            ? const Color(0xFFFFD54A)
            : dimmed
            ? LotlotColors.danger.withValues(alpha: 0.35)
            : inFormation
            ? LotlotColors.danger
            : LotlotColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : (inFormation ? 2.4 : 1.8)
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawLine(
        Offset(xAt(i), yAt(slice[i].close)),
        Offset(xAt(i + 1), yAt(slice[i + 1].close)),
        paint,
      );
    }

    // Formation band fill (web overlay datasets)
    for (final r in formationRanges) {
      if (r.end < r.start || r.start >= n) continue;
      final s = r.start.clamp(0, n - 1);
      final e = r.end.clamp(0, n - 1);
      final band = Path()..moveTo(xAt(s), size.height);
      for (var i = s; i <= e; i++) {
        band.lineTo(xAt(i), yAt(slice[i].close));
      }
      band
        ..lineTo(xAt(e), size.height)
        ..close();
      final selected = r.normIdx == selectedNormIdx;
      final dimmed = selectedNormIdx != null && !selected;
      final color = selected ? const Color(0xFFFFD54A) : LotlotColors.danger;
      canvas.drawPath(
        band,
        Paint()
          ..color = color.withValues(
            alpha: selected ? 0.2 : (dimmed ? 0.06 : 0.12),
          ),
      );
      // Dashed-ish overlay stroke
      final overlay = Paint()
        ..color = color.withValues(alpha: dimmed ? 0.35 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2.2
        ..isAntiAlias = true;
      for (var i = s; i < e; i++) {
        canvas.drawLine(
          Offset(xAt(i), yAt(slice[i].close)),
          Offset(xAt(i + 1), yAt(slice[i + 1].close)),
          overlay,
        );
      }
    }

    _drawPriceLabel(canvas, size, chartWidth, maxY, 0);
    _drawPriceLabel(
      canvas,
      size,
      chartWidth,
      (minY + maxY) / 2,
      size.height / 2,
    );
    _drawPriceLabel(canvas, size, chartWidth, minY, size.height - 14);
  }

  void _drawPriceLabel(
    Canvas canvas,
    Size size,
    double chartWidth,
    double value,
    double top,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: '₺${value.toStringAsFixed(2)}',
        style: const TextStyle(color: LotlotColors.textSecondary, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(0, size.width - chartWidth - 4));
    painter.paint(canvas, Offset(chartWidth + 4, top));
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.displayCount != displayCount ||
      oldDelegate.formationRanges != formationRanges ||
      oldDelegate.selectedNormIdx != selectedNormIdx;
}
