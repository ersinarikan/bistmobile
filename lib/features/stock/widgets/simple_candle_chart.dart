import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../stock_detail_controller.dart';

/// Sade mum + SMA(20) + opsiyonel S/R — thin client (web Lightweight’ın mobil özeti).
class SimpleCandleChart extends StatefulWidget {
  const SimpleCandleChart({
    super.key,
    required this.bars,
    this.levels,
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? levels;

  @override
  State<SimpleCandleChart> createState() => _SimpleCandleChartState();
}

class _SimpleCandleChartState extends State<SimpleCandleChart> {
  int? _selected;

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

    // Web’e yakın pencere: son ~120 bar (çok sıkışmayı önler).
    final display = widget.bars.length > 120
        ? widget.bars.sublist(widget.bars.length - 120)
        : widget.bars;
    final closes = display.map((b) => b.close).toList();
    final ma = _sma(closes, 20);

    var minY = display.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    var maxY = display.map((b) => b.high).reduce((a, b) => a > b ? a : b);
    final support = widget.levels?['support'];
    final resistance = widget.levels?['resistance'];
    if (support is num) {
      final s = support.toDouble();
      if (s < minY) minY = s;
    }
    if (resistance is num) {
      final r = resistance.toDouble();
      if (r > maxY) maxY = r;
    }
    final pad = (maxY - minY) * 0.06;
    minY -= pad;
    maxY += pad;
    if (maxY <= minY) maxY = minY + 1;

    final sel = _selected != null &&
            _selected! >= 0 &&
            _selected! < display.length
        ? display[_selected!]
        : display.last;
    final selMa = _selected != null &&
            _selected! >= 0 &&
            _selected! < ma.length
        ? ma[_selected!]
        : ma.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarInfo(bar: sel, ma20: selMa),
          const SizedBox(height: 6),
          const Text(
            'Yeşil/kırmızı mum · gri: 20g ortalama',
            style: TextStyle(
              fontSize: 11,
              color: LotlotColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(d.localPosition.dx, constraints.maxWidth, display.length),
                  onHorizontalDragUpdate: (d) =>
                      _pick(d.localPosition.dx, constraints.maxWidth, display.length),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 260),
                    painter: _CandlePainter(
                      bars: display,
                      ma: ma,
                      minY: minY,
                      maxY: maxY,
                      selected: _selected ?? display.length - 1,
                      support:
                          support is num ? support.toDouble() : null,
                      resistance:
                          resistance is num ? resistance.toDouble() : null,
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
}

class _BarInfo extends StatelessWidget {
  const _BarInfo({required this.bar, this.ma20});

  final OhlcvBar bar;
  final double? ma20;

  @override
  Widget build(BuildContext context) {
    final up = bar.close >= bar.open;
    final dt = DateTime.fromMillisecondsSinceEpoch(bar.time * 1000, isUtc: true)
        .toLocal();
    final date =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    return Text(
      '$date  O ${_fmt(bar.open)}  H ${_fmt(bar.high)}  '
      'L ${_fmt(bar.low)}  C ${_fmt(bar.close)}'
      '${ma20 != null ? '  · MA20 ${_fmt(ma20!)}' : ''}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: up ? LotlotColors.accent : LotlotColors.danger,
        height: 1.3,
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(1);
    if (v >= 100) return v.toStringAsFixed(2);
    return v.toStringAsFixed(2);
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.bars,
    required this.ma,
    required this.minY,
    required this.maxY,
    required this.selected,
    this.support,
    this.resistance,
  });

  final List<OhlcvBar> bars;
  final List<double?> ma;
  final double minY;
  final double maxY;
  final int selected;
  final double? support;
  final double? resistance;

  static const _left = 44.0;
  static const _right = 8.0;
  static const _top = 8.0;
  static const _bottom = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || bars.isEmpty) return;

    _drawGrid(canvas, plot);
    _drawLevels(canvas, plot);
    _drawCandles(canvas, plot);
    _drawMa(canvas, plot);
    _drawSelected(canvas, plot);
    _drawYLabels(canvas, size, plot);
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
      const dash = 6.0;
      const gap = 4.0;
      var x = plot.left;
      while (x < plot.right) {
        final x2 = (x + dash).clamp(plot.left, plot.right);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += dash + gap;
      }
    }

    dash(support, LotlotColors.accent.withValues(alpha: 0.55));
    dash(resistance, LotlotColors.warning.withValues(alpha: 0.7));
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
      final yHigh = _y(plot, b.high);
      final yLow = _y(plot, b.low);
      final yOpen = _y(plot, b.open);
      final yClose = _y(plot, b.close);

      final wick = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, yHigh), Offset(cx, yLow), wick);

      final top = yOpen < yClose ? yOpen : yClose;
      final bot = yOpen < yClose ? yClose : yOpen;
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

  void _drawMa(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = LotlotColors.textSecondary.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final path = Path();
    var started = false;
    final n = bars.length;
    for (var i = 0; i < ma.length; i++) {
      final v = ma[i];
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

  void _drawSelected(Canvas canvas, Rect plot) {
    final n = bars.length;
    if (selected < 0 || selected >= n) return;
    final cx = _x(plot, selected, n);
    final paint = Paint()
      ..color = LotlotColors.textPrimary.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, plot.top), Offset(cx, plot.bottom), paint);
  }

  void _drawYLabels(Canvas canvas, Size size, Rect plot) {
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
  bool shouldRepaint(covariant _CandlePainter old) {
    return old.bars != bars ||
        old.ma != ma ||
        old.minY != minY ||
        old.maxY != maxY ||
        old.selected != selected ||
        old.support != support ||
        old.resistance != resistance;
  }
}
