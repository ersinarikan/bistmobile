import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../stock_detail_controller.dart';

/// Sade mum + SMA(20) — yalnızca görsel (tier/sinyal hesaplanmaz).
class SimpleCandleChart extends StatelessWidget {
  const SimpleCandleChart({
    super.key,
    required this.bars,
    this.levels,
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? levels;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
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

    final display = bars.length > 90 ? bars.sublist(bars.length - 90) : bars;
    final closes = display.map((b) => b.close).toList();
    final ma = _sma(closes, 20);

    var minY = display.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    var maxY = display.map((b) => b.high).reduce((a, b) => a > b ? a : b);
    final support = levels?['support'];
    final resistance = levels?['resistance'];
    if (support is num) {
      final s = support.toDouble();
      if (s < minY) minY = s;
    }
    if (resistance is num) {
      final r = resistance.toDouble();
      if (r > maxY) maxY = r;
    }
    final pad = (maxY - minY) * 0.05;
    minY -= pad;
    maxY += pad;
    if (maxY <= minY) {
      maxY = minY + 1;
    }

    final candleSpots = <CandlestickSpot>[
      for (var i = 0; i < display.length; i++)
        CandlestickSpot(
          x: i.toDouble(),
          open: display[i].open,
          high: display[i].high,
          low: display[i].low,
          close: display[i].close,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            'Gri çizgi: 20 günlük ortalama',
            style: TextStyle(
              fontSize: 11,
              color: LotlotColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: Stack(
            children: [
              CandlestickChart(
                CandlestickChartData(
                  minY: minY,
                  maxY: maxY,
                  candlestickSpots: candleSpots,
                  candlestickPainter: DefaultCandlestickPainter(
                    candlestickStyleProvider: (spot, _) {
                      final c = spot.isUp
                          ? LotlotColors.accent
                          : LotlotColors.danger;
                      return CandlestickStyle(
                        lineColor: c,
                        lineWidth: 1.2,
                        bodyStrokeColor: c,
                        bodyStrokeWidth: 0,
                        bodyFillColor: c,
                        bodyWidth: 5,
                        bodyRadius: 0,
                      );
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: LotlotColors.border,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  candlestickTouchData: CandlestickTouchData(enabled: false),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _OverlayPainter(
                    minY: minY,
                    maxY: maxY,
                    barCount: display.length,
                    ma: ma,
                    support: support is num ? support.toDouble() : null,
                    resistance:
                        resistance is num ? resistance.toDouble() : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// SMA; ilk period-1 değer null.
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

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.minY,
    required this.maxY,
    required this.barCount,
    required this.ma,
    this.support,
    this.resistance,
  });

  final double minY;
  final double maxY;
  final int barCount;
  final List<double?> ma;
  final double? support;
  final double? resistance;

  double _y(Size size, double value) {
    final range = maxY - minY;
    if (range <= 0) return size.height / 2;
    return size.height * (1 - (value - minY) / range);
  }

  double _x(Size size, int i) {
    if (barCount <= 1) return size.width / 2;
    return size.width * i / (barCount - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final maPaint = Paint()
      ..color = LotlotColors.textSecondary.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    var started = false;
    for (var i = 0; i < ma.length; i++) {
      final v = ma[i];
      if (v == null) continue;
      final p = Offset(_x(size, i), _y(size, v));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, maPaint);

    void dashH(double yVal, Color color) {
      final y = _y(size, yVal);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      const dash = 6.0;
      const gap = 4.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y),
          paint,
        );
        x += dash + gap;
      }
    }

    if (support != null) {
      dashH(support!, LotlotColors.accent.withValues(alpha: 0.55));
    }
    if (resistance != null) {
      dashH(resistance!, LotlotColors.warning.withValues(alpha: 0.65));
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) {
    return old.minY != minY ||
        old.maxY != maxY ||
        old.barCount != barCount ||
        old.support != support ||
        old.resistance != resistance ||
        old.ma != ma;
  }
}
