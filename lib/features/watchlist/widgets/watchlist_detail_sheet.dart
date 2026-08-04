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

const _sparkExcludedSources = {'ML_PREDICTOR', 'ENHANCED_ML', 'FINGPT'};

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wl.lastError!)),
      );
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
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? pattern;
  final bool showFormations;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ranges = showFormations
        ? _sparkFormationRanges(
            pattern: pattern,
            displayCount: math.min(120, bars.length),
            fullBarsLength: bars.length,
          )
        : const <({int start, int end})>[];

    return Material(
      color: LotlotColors.surface,
      borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      child: InkWell(
        onTap: bars.isEmpty ? null : onOpen,
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
              SizedBox(
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
                          formationRanges: ranges,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
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
                  if (showFormations && ranges.isNotEmpty)
                    const Text(
                      'Formasyon',
                      style: TextStyle(
                        color: LotlotColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

/// Web `_normalizePatternRanges` — görünen spark dilimine index.
List<({int start, int end})> _sparkFormationRanges({
  required Map<String, dynamic>? pattern,
  required int displayCount,
  required int fullBarsLength,
}) {
  if (pattern == null || displayCount <= 0) return const [];
  final raw = pattern['patterns'];
  if (raw is! List) return const [];

  var maxIx = -1;
  final eligible = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final src = (m['source'] ?? '').toString().toUpperCase();
    if (src.isEmpty || _sparkExcludedSources.contains(src)) continue;
    final rec = (m['recency_bucket'] ?? '').toString().toUpperCase();
    final conf = m['confidence'];
    final confN = conf is num ? conf.toDouble() : 0.0;
    if (rec == 'STALE' && confN < 0.35) continue;
    if (rec == 'INVALID') continue;
    final range = m['range'];
    if (range is! Map) continue;
    final s = range['start_index'];
    final e = range['end_index'];
    if (s is! num || e is! num) continue;
    maxIx = math.max(maxIx, math.max(s.round(), e.round()));
    eligible.add(m);
  }

  final apiPts = pattern['data_points'];
  final apiN = apiPts is num && apiPts > 0 ? apiPts.toInt() : 0;
  final totalPoints = math.max(
    math.max(apiN, maxIx < 0 ? 0 : maxIx + 1),
    math.max(displayCount, fullBarsLength),
  );
  final offset = math.max(0, totalPoints - displayCount);

  final out = <({int start, int end})>[];
  for (final m in eligible) {
    final range = m['range'] as Map;
    var start = (range['start_index'] as num).round() - offset;
    var end = (range['end_index'] as num).round() - offset;
    if (end < 0 || start >= displayCount) continue;
    start = start.clamp(0, displayCount - 1);
    end = end.clamp(0, displayCount - 1);
    if (end < start) continue;
    out.add((start: start, end: end));
  }
  return out;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.bars,
    this.formationRanges = const [],
  });

  final List<OhlcvBar> bars;
  final List<({int start, int end})> formationRanges;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final take = math.min(120, bars.length);
    final slice = bars.sublist(bars.length - take);
    final n = slice.length;
    var minY = slice.map((b) => b.low).reduce(math.min);
    var maxY = slice.map((b) => b.high).reduce(math.max);
    if (maxY <= minY) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    double xAt(int i) =>
        n == 1 ? size.width / 2 : i * size.width / (n - 1);
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
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [
            LotlotColors.accent.withValues(alpha: 0.22),
            LotlotColors.accent.withValues(alpha: 0.02),
          ],
        ),
    );

    // Base line (accent), segment-colored on formations like web Chart.js
    for (var i = 0; i < n - 1; i++) {
      final inFormation = formationRanges.any(
        (r) => i >= r.start && i <= r.end,
      );
      final paint = Paint()
        ..color = inFormation ? LotlotColors.danger : LotlotColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = inFormation ? 2.4 : 1.8
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
      canvas.drawPath(
        band,
        Paint()..color = LotlotColors.danger.withValues(alpha: 0.12),
      );
      // Dashed-ish overlay stroke
      final overlay = Paint()
        ..color = LotlotColors.danger.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true;
      for (var i = s; i < e; i++) {
        canvas.drawLine(
          Offset(xAt(i), yAt(slice[i].close)),
          Offset(xAt(i + 1), yAt(slice[i + 1].close)),
          overlay,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.formationRanges != formationRanges;
}
