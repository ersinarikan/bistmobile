import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import '../stock_detail_controller.dart';

enum ChartDetailMode { simple, detailed }

/// Mum + hacim + Sade/Detaylı (EMA50/BB/RSI/öngörü) + Pro formasyon gölgesi.
class SimpleCandleChart extends StatefulWidget {
  const SimpleCandleChart({
    super.key,
    required this.bars,
    this.levels,
    this.forecasts = const [],
    this.patternRanges = const [],
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? levels;
  final List<Map<String, dynamic>> forecasts;
  /// Absolute bar indices in full `bars` series: {start, end, bullish?}
  final List<({int start, int end, bool bullish})> patternRanges;

  @override
  State<SimpleCandleChart> createState() => _SimpleCandleChartState();
}

class _SimpleCandleChartState extends State<SimpleCandleChart> {
  int? _selected;
  int _barCount = 120;
  ChartDetailMode _mode = ChartDetailMode.simple;
  bool _showFormationShade = false;

  static const _barOptions = [60, 120, 200, 300];

  @override
  Widget build(BuildContext context) {
    if (widget.bars.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Grafik verisi yok',
            style: TextStyle(color: LotlotColors.textSecondary),
          ),
        ),
      );
    }

    final take = math.min(_barCount, widget.bars.length);
    final display = widget.bars.sublist(widget.bars.length - take);
    final offset = widget.bars.length - display.length;
    final closes = display.map((b) => b.close).toList();
    final ma20 = _sma(closes, 20);
    final ma50 = _sma(closes, 50);
    final bb = _bollinger(closes, 20, 2);
    final rsi = _rsi(closes, 14);

    var minY = display.map((b) => b.low).reduce(math.min);
    var maxY = display.map((b) => b.high).reduce(math.max);
    final support = widget.levels?['support'];
    final resistance = widget.levels?['resistance'];
    if (support is num) minY = math.min(minY, support.toDouble());
    if (resistance is num) maxY = math.max(maxY, resistance.toDouble());
    if (_mode == ChartDetailMode.detailed) {
      for (final v in [...ma50, ...bb.$1, ...bb.$2]) {
        if (v != null) {
          minY = math.min(minY, v);
          maxY = math.max(maxY, v);
        }
      }
      for (final f in widget.forecasts) {
        final p = f['price'] ?? f['close'] ?? f['value'];
        if (p is num) {
          minY = math.min(minY, p.toDouble());
          maxY = math.max(maxY, p.toDouble());
        }
      }
    }
    final pad = (maxY - minY) * 0.06;
    minY -= pad;
    maxY += pad;
    if (maxY <= minY) maxY = minY + 1;

    final selIdx = (_selected ?? display.length - 1).clamp(0, display.length - 1);
    final sel = display[selIdx];
    final detailed = _mode == ChartDetailMode.detailed;
    final session = context.watch<SessionController>();

    final localRanges = <({int start, int end, bool bullish})>[];
    if (_showFormationShade && session.isPro) {
      for (final r in widget.patternRanges) {
        final s = r.start - offset;
        final e = r.end - offset;
        if (e < 0 || s >= display.length) continue;
        localRanges.add((
          start: s.clamp(0, display.length - 1),
          end: e.clamp(0, display.length - 1),
          bullish: r.bullish,
        ));
      }
    }

    final candleH = detailed ? 220.0 : 240.0;
    final volH = 56.0;
    final rsiH = detailed ? 48.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarInfo(
            bar: sel,
            ma20: ma20[selIdx],
            ma50: detailed ? ma50[selIdx] : null,
            rsi: detailed ? rsi[selIdx] : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              SegmentedButton<ChartDetailMode>(
                segments: const [
                  ButtonSegment(
                    value: ChartDetailMode.simple,
                    label: Text('Sade'),
                  ),
                  ButtonSegment(
                    value: ChartDetailMode.detailed,
                    label: Text('Detaylı'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return LotlotColors.accent;
                    }
                    return LotlotColors.textSecondary;
                  }),
                ),
              ),
              ..._barOptions.map((n) {
                final selN = _barCount == n;
                return ChoiceChip(
                  label: Text('$n'),
                  selected: selN,
                  onSelected: (_) => setState(() => _barCount = n),
                  visualDensity: VisualDensity.compact,
                  selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selN ? LotlotColors.accent : LotlotColors.textSecondary,
                    fontWeight: selN ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selN ? LotlotColors.accent : LotlotColors.border,
                  ),
                  backgroundColor: LotlotColors.surface,
                );
              }),
              if (detailed)
                FilterChip(
                  label: const Text('Formasyon'),
                  selected: _showFormationShade,
                  onSelected: (v) async {
                    if (v && !session.isPro) {
                      await showSoftGateSheet(
                        context,
                        kind: SoftGateKind.pro,
                      );
                      return;
                    }
                    setState(() => _showFormationShade = v);
                  },
                  visualDensity: VisualDensity.compact,
                  selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _showFormationShade
                        ? LotlotColors.accent
                        : LotlotColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: _showFormationShade
                        ? LotlotColors.accent
                        : LotlotColors.border,
                  ),
                  backgroundColor: LotlotColors.surface,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detailed
                ? 'Mum · MA20/50 · BB · hacim · RSI · öngörü'
                : 'Mum · MA20 · hacim · S/R',
            style: const TextStyle(
              fontSize: 11,
              color: LotlotColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: candleH + volH + rsiH + 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(
                    d.localPosition.dx,
                    constraints.maxWidth,
                    display.length,
                  ),
                  onHorizontalDragUpdate: (d) => _pick(
                    d.localPosition.dx,
                    constraints.maxWidth,
                    display.length,
                  ),
                  child: CustomPaint(
                    size: Size(
                      constraints.maxWidth,
                      candleH + volH + rsiH + 8,
                    ),
                    painter: _ChartPainter(
                      bars: display,
                      ma20: ma20,
                      ma50: detailed ? ma50 : const [],
                      bbLower: detailed ? bb.$1 : const [],
                      bbUpper: detailed ? bb.$2 : const [],
                      rsi: detailed ? rsi : const [],
                      forecasts: detailed ? widget.forecasts : const [],
                      patternRanges: localRanges,
                      minY: minY,
                      maxY: maxY,
                      selected: selIdx,
                      support: support is num ? support.toDouble() : null,
                      resistance:
                          resistance is num ? resistance.toDouble() : null,
                      candleHeight: candleH,
                      volumeHeight: volH,
                      rsiHeight: rsiH,
                      detailed: detailed,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _pick(double dx, double width, int count) {
    if (count <= 0 || width <= 0) return;
    const leftPad = 44.0;
    const rightPad = 8.0;
    final plotW = (width - leftPad - rightPad).clamp(1.0, width);
    final x = ((dx - leftPad) / plotW).clamp(0.0, 1.0);
    final i = (x * (count - 1)).round().clamp(0, count - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  static List<double?> _sma(List<double> closes, int period) {
    final out = List<double?>.filled(closes.length, null);
    if (closes.length < period) return out;
    var sum = 0.0;
    for (var i = 0; i < closes.length; i++) {
      sum += closes[i];
      if (i >= period) sum -= closes[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  static (List<double?>, List<double?>) _bollinger(
    List<double> closes,
    int period,
    double k,
  ) {
    final mid = _sma(closes, period);
    final lower = List<double?>.filled(closes.length, null);
    final upper = List<double?>.filled(closes.length, null);
    for (var i = period - 1; i < closes.length; i++) {
      final m = mid[i];
      if (m == null) continue;
      var sumSq = 0.0;
      for (var j = i - period + 1; j <= i; j++) {
        final d = closes[j] - m;
        sumSq += d * d;
      }
      final std = math.sqrt(sumSq / period);
      lower[i] = m - k * std;
      upper[i] = m + k * std;
    }
    return (lower, upper);
  }

  static List<double?> _rsi(List<double> closes, int period) {
    final out = List<double?>.filled(closes.length, null);
    if (closes.length <= period) return out;
    var gain = 0.0;
    var loss = 0.0;
    for (var i = 1; i <= period; i++) {
      final d = closes[i] - closes[i - 1];
      if (d >= 0) {
        gain += d;
      } else {
        loss -= d;
      }
    }
    var avgGain = gain / period;
    var avgLoss = loss / period;
    out[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    for (var i = period + 1; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      final g = d > 0 ? d : 0.0;
      final l = d < 0 ? -d : 0.0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      out[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    return out;
  }
}

class _BarInfo extends StatelessWidget {
  const _BarInfo({
    required this.bar,
    this.ma20,
    this.ma50,
    this.rsi,
  });

  final OhlcvBar bar;
  final double? ma20;
  final double? ma50;
  final double? rsi;

  @override
  Widget build(BuildContext context) {
    final up = bar.close >= bar.open;
    final dt = DateTime.fromMillisecondsSinceEpoch(bar.time * 1000, isUtc: true)
        .toLocal();
    final date =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    return Text(
      [
        '$date  O ${_fmt(bar.open)}  H ${_fmt(bar.high)}  '
            'L ${_fmt(bar.low)}  C ${_fmt(bar.close)}',
        if (ma20 != null) 'MA20 ${_fmt(ma20!)}',
        if (ma50 != null) 'MA50 ${_fmt(ma50!)}',
        if (rsi != null) 'RSI ${rsi!.toStringAsFixed(0)}',
        if (bar.volume != null) 'V ${_fmtVol(bar.volume!)}',
      ].join('  · '),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: up ? LotlotColors.accent : LotlotColors.danger,
        height: 1.35,
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  static String _fmtVol(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.bars,
    required this.ma20,
    required this.ma50,
    required this.bbLower,
    required this.bbUpper,
    required this.rsi,
    required this.forecasts,
    required this.patternRanges,
    required this.minY,
    required this.maxY,
    required this.selected,
    required this.candleHeight,
    required this.volumeHeight,
    required this.rsiHeight,
    required this.detailed,
    this.support,
    this.resistance,
  });

  final List<OhlcvBar> bars;
  final List<double?> ma20;
  final List<double?> ma50;
  final List<double?> bbLower;
  final List<double?> bbUpper;
  final List<double?> rsi;
  final List<Map<String, dynamic>> forecasts;
  final List<({int start, int end, bool bullish})> patternRanges;
  final double minY;
  final double maxY;
  final int selected;
  final double candleHeight;
  final double volumeHeight;
  final double rsiHeight;
  final bool detailed;
  final double? support;
  final double? resistance;

  static const _left = 44.0;
  static const _right = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final candlePlot = Rect.fromLTRB(
      _left,
      4,
      size.width - _right,
      candleHeight,
    );
    final volPlot = Rect.fromLTRB(
      _left,
      candleHeight + 4,
      size.width - _right,
      candleHeight + volumeHeight,
    );
    final rsiPlot = rsiHeight > 0
        ? Rect.fromLTRB(
            _left,
            candleHeight + volumeHeight + 8,
            size.width - _right,
            candleHeight + volumeHeight + rsiHeight + 8,
          )
        : null;
    if (bars.isEmpty || candlePlot.width <= 0) return;

    _drawFormationShade(canvas, candlePlot);
    _drawGrid(canvas, candlePlot);
    _drawLevels(canvas, candlePlot);
    if (detailed) {
      _drawBand(canvas, candlePlot, bbLower, bbUpper);
      _drawLineSeries(
        canvas,
        candlePlot,
        ma50,
        LotlotColors.warning.withValues(alpha: 0.85),
        1.2,
      );
    }
    _drawCandles(canvas, candlePlot);
    _drawLineSeries(
      canvas,
      candlePlot,
      ma20,
      LotlotColors.textSecondary.withValues(alpha: 0.9),
      1.5,
    );
    if (detailed) _drawForecasts(canvas, candlePlot);
    _drawSelected(canvas, candlePlot, volPlot, rsiPlot);
    _drawVolume(canvas, volPlot);
    if (rsiPlot != null) _drawRsi(canvas, rsiPlot);
    _drawYLabels(canvas, candlePlot);
  }

  void _drawFormationShade(Canvas canvas, Rect plot) {
    final n = bars.length;
    for (final r in patternRanges) {
      if (r.end < r.start) continue;
      final x1 = _x(plot, r.start, n) - plot.width / n / 2;
      final x2 = _x(plot, r.end, n) + plot.width / n / 2;
      final color = (r.bullish ? LotlotColors.accent : LotlotColors.danger)
          .withValues(alpha: 0.12);
      canvas.drawRect(
        Rect.fromLTRB(x1, plot.top, x2, plot.bottom),
        Paint()..color = color,
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = LotlotColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
  }

  void _drawLevels(Canvas canvas, Rect plot) {
    void dash(double? price, Color color) {
      if (price == null) return;
      final y = _y(plot, price);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.1;
      var x = plot.left;
      while (x < plot.right) {
        final x2 = (x + 6).clamp(plot.left, plot.right);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += 10;
      }
    }

    dash(support, LotlotColors.accent.withValues(alpha: 0.55));
    dash(resistance, LotlotColors.warning.withValues(alpha: 0.7));
  }

  void _drawBand(
    Canvas canvas,
    Rect plot,
    List<double?> lower,
    List<double?> upper,
  ) {
    final n = bars.length;
    final path = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final u = i < upper.length ? upper[i] : null;
      if (u == null) continue;
      final p = Offset(_x(plot, i, n), _y(plot, u));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      final l = i < lower.length ? lower[i] : null;
      if (l == null) continue;
      path.lineTo(_x(plot, i, n), _y(plot, l));
    }
    if (started) {
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = LotlotColors.accent.withValues(alpha: 0.08),
      );
    }
  }

  void _drawCandles(Canvas canvas, Rect plot) {
    final n = bars.length;
    final slot = plot.width / n;
    final bodyW = (slot * 0.62).clamp(1.5, 10.0);
    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final up = b.close >= b.open;
      final color = up ? LotlotColors.accent : LotlotColors.danger;
      final cx = _x(plot, i, n);
      canvas.drawLine(
        Offset(cx, _y(plot, b.high)),
        Offset(cx, _y(plot, b.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      final yOpen = _y(plot, b.open);
      final yClose = _y(plot, b.close);
      final top = math.min(yOpen, yClose);
      final bot = math.max(yOpen, yClose);
      final h = (bot - top).clamp(1.0, plot.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, top + h / 2),
            width: bodyW,
            height: h,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
  }

  void _drawLineSeries(
    Canvas canvas,
    Rect plot,
    List<double?> series,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final path = Path();
    var started = false;
    final n = bars.length;
    for (var i = 0; i < series.length && i < n; i++) {
      final v = series[i];
      if (v == null) continue;
      final p = Offset(_x(plot, i, n), _y(plot, v));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, paint);
  }

  void _drawForecasts(Canvas canvas, Rect plot) {
    if (forecasts.isEmpty || bars.isEmpty) return;
    final last = bars.last.close;
    final n = bars.length;
    final paint = Paint()
      ..color = LotlotColors.accentMuted.withValues(alpha: 0.9)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(_x(plot, n - 1, n), _y(plot, last));
    final step = math.max(1, (plot.width / n).round());
    var i = 0;
    for (final f in forecasts.take(8)) {
      final p = f['price'] ?? f['close'] ?? f['value'];
      if (p is! num) continue;
      i++;
      final x = plot.right - step * (forecasts.length - i).clamp(0, 20);
      path.lineTo(x.clamp(plot.left, plot.right), _y(plot, p.toDouble()));
    }
    canvas.drawPath(
      path,
      paint
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawVolume(Canvas canvas, Rect plot) {
    final vols = bars.map((b) => b.volume ?? 0.0).toList();
    final maxV = vols.fold<double>(0, math.max);
    if (maxV <= 0) return;
    final n = bars.length;
    final slot = plot.width / n;
    final w = (slot * 0.7).clamp(1.0, 8.0);
    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final v = b.volume ?? 0;
      if (v <= 0) continue;
      final h = plot.height * (v / maxV);
      final up = b.close >= b.open;
      final cx = _x(plot, i, n);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, plot.bottom - h / 2),
          width: w,
          height: h.clamp(1.0, plot.height),
        ),
        Paint()
          ..color = (up ? LotlotColors.accent : LotlotColors.danger)
              .withValues(alpha: 0.35),
      );
    }
  }

  void _drawRsi(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = LotlotColors.border
      ..strokeWidth = 0.6;
    for (final level in [30.0, 70.0]) {
      final y = plot.top + plot.height * (1 - level / 100);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
    _drawLineSeriesInUnit(
      canvas,
      plot,
      rsi,
      LotlotColors.warning,
      (v) => v / 100,
    );
  }

  void _drawLineSeriesInUnit(
    Canvas canvas,
    Rect plot,
    List<double?> series,
    Color color,
    double Function(double) norm,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    final n = bars.length;
    for (var i = 0; i < series.length && i < n; i++) {
      final v = series[i];
      if (v == null) continue;
      final y = plot.top + plot.height * (1 - norm(v).clamp(0.0, 1.0));
      final p = Offset(_x(plot, i, n), y);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, paint);
  }

  void _drawSelected(
    Canvas canvas,
    Rect candle,
    Rect vol,
    Rect? rsiPlot,
  ) {
    final n = bars.length;
    if (selected < 0 || selected >= n) return;
    final cx = _x(candle, selected, n);
    final paint = Paint()
      ..color = LotlotColors.textPrimary.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, candle.top), Offset(cx, vol.bottom), paint);
    if (rsiPlot != null) {
      canvas.drawLine(
        Offset(cx, rsiPlot.top),
        Offset(cx, rsiPlot.bottom),
        paint,
      );
    }
  }

  void _drawYLabels(Canvas canvas, Rect plot) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final t = i / 4;
      final price = maxY - (maxY - minY) * t;
      final y = plot.top + plot.height * t;
      tp.text = TextSpan(
        text: _priceLabel(price),
        style: const TextStyle(
          color: LotlotColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout(maxWidth: _left - 4);
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }
  }

  double _x(Rect plot, int i, int n) {
    if (n <= 1) return plot.center.dx;
    final slot = plot.width / n;
    return plot.left + slot * (i + 0.5);
  }

  double _y(Rect plot, double value) {
    final range = maxY - minY;
    if (range <= 0) return plot.center.dy;
    return plot.top + plot.height * (1 - (value - minY) / range);
  }

  static String _priceLabel(double v) {
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
