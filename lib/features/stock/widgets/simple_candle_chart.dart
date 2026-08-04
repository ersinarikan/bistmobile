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
    this.forceDetailed = false,
    this.showForecastToggle = false,
    this.forecastEnabled = false,
    this.onForecastChanged,
    this.publicPreview = false,
    this.onPublicTap,
  });

  final List<OhlcvBar> bars;
  final Map<String, dynamic>? levels;
  final List<Map<String, dynamic>> forecasts;
  /// Absolute bar indices in full `bars` series: {start, end, bullish?}
  final List<({int start, int end, bool bullish})> patternRanges;
  /// Büyük grafik: Öngörü açıkken Detaylı katmanı zorla.
  final bool forceDetailed;
  final bool showForecastToggle;
  final bool forecastEnabled;
  final ValueChanged<bool?>? onForecastChanged;

  /// Web `/hisse` guest chart — view-only; tap → [onPublicTap] (login).
  final bool publicPreview;
  final VoidCallback? onPublicTap;

  @override
  State<SimpleCandleChart> createState() => _SimpleCandleChartState();
}

class _SimpleCandleChartState extends State<SimpleCandleChart> {
  int? _selected;
  int _barCount = 60;
  ChartDetailMode _mode = ChartDetailMode.simple;
  // Web `#chartModal` checkbox parity (Sade/Detaylı = preset)
  bool _showVolume = true;
  bool _showEma20 = false;
  bool _showEma50 = false;
  bool _showBb = false;
  bool _showRsi = false;
  bool _showSr = true;
  bool _showFormationShade = false;
  bool _localShowForecast = false;

  static const _barOptions = [60, 100, 200, 300, 400];

  bool get _forecastEnabled =>
      widget.showForecastToggle ? widget.forecastEnabled : _localShowForecast;

  void _applyPreset(ChartDetailMode mode) {
    _mode = mode;
    if (mode == ChartDetailMode.simple) {
      _showVolume = true;
      _showEma20 = false;
      _showEma50 = false;
      _showBb = false;
      _showRsi = false;
      _showSr = true;
    } else {
      _showVolume = true;
      _showEma20 = true;
      _showEma50 = true;
      _showBb = true;
      _showRsi = true;
      _showSr = true;
    }
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? LotlotColors.accent : LotlotColors.textSecondary,
      ),
      side: BorderSide(
        color: selected ? LotlotColors.accent : LotlotColors.border,
      ),
      backgroundColor: LotlotColors.surface,
    );
  }

  String _legendText({required bool showForecastLine}) {
    final parts = <String>['Mum'];
    if (_showEma20) parts.add('Sarı: EMA20');
    if (_showEma50) parts.add('Mavi: EMA50');
    if (_showBb) parts.add('Mint bant: Bollinger');
    if (_showSr) parts.add('Yeşil/sarı kesik: Destek/Direnç');
    if (_showVolume) parts.add('Hacim');
    if (_showRsi) parts.add('RSI paneli');
    if (_showFormationShade) parts.add('Gölge: Formasyon');
    if (showForecastLine) parts.add('Kırmızı kesikli: Öngörü');
    return parts.join(' · ');
  }

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

    final take = math.min(
      widget.publicPreview ? 180 : _barCount,
      widget.bars.length,
    );
    final display = widget.bars.sublist(widget.bars.length - take);
    final offset = widget.bars.length - display.length;
    final closes = display.map((b) => b.close).toList();
    final ema20 = _ema(closes, 20);
    final ema50 = _ema(closes, 50);
    final bb = _bollinger(closes, 20, 2);
    final rsi = _rsi(closes, 14);

    var minY = display.map((b) => b.low).reduce(math.min);
    var maxY = display.map((b) => b.high).reduce(math.max);
    final support = widget.levels?['support'];
    final resistance = widget.levels?['resistance'];
    if (_showSr) {
      if (support is num) minY = math.min(minY, support.toDouble());
      if (resistance is num) maxY = math.max(maxY, resistance.toDouble());
    }
    if (_showEma20 || _showEma50 || _showBb) {
      for (final v in [
        if (_showEma20) ...ema20,
        if (_showEma50) ...ema50,
        if (_showBb) ...bb.$1,
        if (_showBb) ...bb.$2,
      ]) {
        if (v != null) {
          minY = math.min(minY, v);
          maxY = math.max(maxY, v);
        }
      }
    }
    final session = context.watch<SessionController>();
    final publicPreview = widget.publicPreview;
    final showVolume = publicPreview ? true : _showVolume;
    final showEma20 = publicPreview ? false : _showEma20;
    final showEma50 = publicPreview ? false : _showEma50;
    final showBb = publicPreview ? false : _showBb;
    final showRsi = publicPreview ? false : _showRsi;
    final showSr = publicPreview ? false : _showSr;
    final showFormationShade =
        publicPreview ? false : _showFormationShade;
    final showForecastLine = !publicPreview &&
        session.isPro &&
        widget.forecasts.isNotEmpty &&
        _forecastEnabled;
    if (showForecastLine) {
      for (final f in widget.forecasts) {
        final p = f['target_price'] ??
            f['price'] ??
            f['close'] ??
            f['value'];
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

    final selIdx =
        (_selected ?? display.length - 1).clamp(0, display.length - 1);
    final sel = display[selIdx];

    final localRanges = <({int start, int end, bool bullish})>[];
    if (showFormationShade && session.isPro) {
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

    final volH = showVolume ? 56.0 : 0.0;
    final rsiH = showRsi ? 48.0 : 0.0;
    const dateH = 18.0;
    final candleH = showRsi || showVolume ? 210.0 : 250.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!publicPreview) ...[
            _BarInfo(
              bar: sel,
              ma20: showEma20 ? ema20[selIdx] : null,
              ma50: showEma50 ? ema50[selIdx] : null,
              rsi: showRsi ? rsi[selIdx] : null,
              detailed: showEma20 || showEma50 || showRsi,
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
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() => _applyPreset(s.first));
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        WidgetStateProperty.resolveWith((states) {
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
                    selectedColor:
                        LotlotColors.accent.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selN
                          ? LotlotColors.accent
                          : LotlotColors.textSecondary,
                      fontWeight:
                          selN ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color:
                          selN ? LotlotColors.accent : LotlotColors.border,
                    ),
                    backgroundColor: LotlotColors.surface,
                  );
                }),
                _toggleChip(
                  label: 'Hacim',
                  selected: _showVolume,
                  onSelected: (v) => setState(() => _showVolume = v),
                ),
                _toggleChip(
                  label: 'EMA20',
                  selected: _showEma20,
                  onSelected: (v) => setState(() => _showEma20 = v),
                ),
                _toggleChip(
                  label: 'EMA50',
                  selected: _showEma50,
                  onSelected: (v) => setState(() => _showEma50 = v),
                ),
                _toggleChip(
                  label: 'Bollinger',
                  selected: _showBb,
                  onSelected: (v) => setState(() => _showBb = v),
                ),
                _toggleChip(
                  label: 'RSI',
                  selected: _showRsi,
                  onSelected: (v) => setState(() => _showRsi = v),
                ),
                _toggleChip(
                  label: 'S/R',
                  selected: _showSr,
                  onSelected: (v) => setState(() => _showSr = v),
                ),
                _toggleChip(
                  label: 'Formasyon',
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
                ),
                _toggleChip(
                  label: 'Öngörü',
                  selected: _forecastEnabled,
                  onSelected: (v) async {
                    if (v && !session.isPro) {
                      await showSoftGateSheet(
                        context,
                        kind: SoftGateKind.pro,
                      );
                      return;
                    }
                    if (widget.showForecastToggle) {
                      widget.onForecastChanged?.call(v);
                    } else {
                      setState(() => _localShowForecast = v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _legendText(showForecastLine: showForecastLine),
              style: const TextStyle(
                fontSize: 11,
                color: LotlotColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Detaylı analiz için giriş yapın',
                style: TextStyle(
                  color: LotlotColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          SizedBox(
            height: candleH + dateH + volH + rsiH + 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chart = CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    candleH + dateH + volH + rsiH + 8,
                  ),
                  painter: _ChartPainter(
                    bars: display,
                    ma20: showEma20 ? ema20 : const [],
                    ma50: showEma50 ? ema50 : const [],
                    bbLower: showBb ? bb.$1 : const [],
                    bbUpper: showBb ? bb.$2 : const [],
                    rsi: showRsi ? rsi : const [],
                    forecasts:
                        showForecastLine ? widget.forecasts : const [],
                    patternRanges: localRanges,
                    minY: minY,
                    maxY: maxY,
                    selected: publicPreview ? display.length - 1 : selIdx,
                    support: showSr && support is num
                        ? support.toDouble()
                        : null,
                    resistance: showSr && resistance is num
                        ? resistance.toDouble()
                        : null,
                    candleHeight: candleH,
                    dateHeight: dateH,
                    volumeHeight: volH,
                    rsiHeight: rsiH,
                    showVolume: showVolume,
                    showBb: showBb,
                    showEma20: showEma20,
                    showEma50: showEma50,
                    showForecast: showForecastLine,
                  ),
                );
                if (publicPreview) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onPublicTap,
                    child: chart,
                  );
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(
                    d.localPosition.dx,
                    constraints.maxWidth,
                    display.length,
                    reserveForecast: showForecastLine,
                  ),
                  onHorizontalDragUpdate: (d) => _pick(
                    d.localPosition.dx,
                    constraints.maxWidth,
                    display.length,
                    reserveForecast: showForecastLine,
                  ),
                  child: chart,
                );
              },
            ),
          ),
          if (publicPreview)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sadece geçmiş fiyat verisi. Yatırım tavsiyesi değildir.',
                style: TextStyle(
                  fontSize: 11,
                  color: LotlotColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pick(
    double dx,
    double width,
    int count, {
    required bool reserveForecast,
  }) {
    if (count <= 0 || width <= 0) return;
    const leftPad = 44.0;
    const rightPad = 8.0;
    final plotW = (width - leftPad - rightPad).clamp(1.0, width);
    final histW = reserveForecast ? plotW * 0.72 : plotW;
    final x = ((dx - leftPad) / histW).clamp(0.0, 0.999);
    final i = (x * count).floor().clamp(0, count - 1);
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

  static List<double?> _ema(List<double> closes, int period) {
    final out = List<double?>.filled(closes.length, null);
    if (closes.length < period) return out;
    var seed = 0.0;
    for (var i = 0; i < period; i++) {
      seed += closes[i];
    }
    var ema = seed / period;
    out[period - 1] = ema;
    final k = 2.0 / (period + 1);
    for (var i = period; i < closes.length; i++) {
      ema = closes[i] * k + ema * (1 - k);
      out[i] = ema;
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
    this.detailed = false,
  });

  final OhlcvBar bar;
  final double? ma20;
  final double? ma50;
  final double? rsi;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final up = bar.close >= bar.open;
    final dt = DateTime.fromMillisecondsSinceEpoch(bar.time * 1000, isUtc: true)
        .toLocal();
    final date =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final change = bar.close - bar.open;
    final changePct = bar.open == 0 ? 0.0 : (change / bar.open) * 100;
    final tone = up ? LotlotColors.accent : LotlotColors.danger;
    final m20Label = detailed ? 'EMA20' : 'MA20';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${change >= 0 ? '+' : ''}${_fmt(change)}  '
                '(${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: tone,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _kv('O', _fmt(bar.open)),
              _kv('H', _fmt(bar.high)),
              _kv('L', _fmt(bar.low)),
              _kv('C', _fmt(bar.close), emphasize: true, color: tone),
              if (bar.volume != null) _kv('Hacim', _fmtVol(bar.volume!)),
              if (ma20 != null) _kv(m20Label, _fmt(ma20!)),
              if (ma50 != null) _kv('EMA50', _fmt(ma50!)),
              if (rsi != null) _kv('RSI', rsi!.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _kv(
    String k,
    String v, {
    bool emphasize = false,
    Color? color,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$k ',
            style: const TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: v,
            style: TextStyle(
              color: color ?? LotlotColors.textPrimary,
              fontSize: emphasize ? 13 : 12,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(1);
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
    required this.dateHeight,
    required this.volumeHeight,
    required this.rsiHeight,
    required this.showVolume,
    required this.showBb,
    required this.showEma20,
    required this.showEma50,
    required this.showForecast,
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
  final double dateHeight;
  final double volumeHeight;
  final double rsiHeight;
  final bool showVolume;
  final bool showBb;
  final bool showEma20;
  final bool showEma50;
  final bool showForecast;
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
    final datePlot = Rect.fromLTRB(
      _left,
      candleHeight,
      size.width - _right,
      candleHeight + dateHeight,
    );
    final volTop = candleHeight + dateHeight + 4;
    final volPlot = Rect.fromLTRB(
      _left,
      volTop,
      size.width - _right,
      volTop + volumeHeight,
    );
    final rsiPlot = rsiHeight > 0
        ? Rect.fromLTRB(
            _left,
            volTop + volumeHeight + 8,
            size.width - _right,
            volTop + volumeHeight + rsiHeight + 8,
          )
        : null;
    if (bars.isEmpty || candlePlot.width <= 0) return;

    _drawFormationShade(canvas, candlePlot);
    _drawGrid(canvas, candlePlot);
    _drawLevels(canvas, candlePlot);
    if (showBb) {
      _drawBand(canvas, candlePlot, bbLower, bbUpper);
    }
    if (showEma20) {
      _drawLineSeries(
        canvas,
        candlePlot,
        ma20,
        LotlotColors.warning.withValues(alpha: 0.95),
        1.5,
      );
    }
    if (showEma50) {
      _drawLineSeries(
        canvas,
        candlePlot,
        ma50,
        const Color(0xFF38BDF8).withValues(alpha: 0.92),
        1.5,
      );
    }
    _drawCandles(canvas, candlePlot);
    if (showForecast) _drawForecasts(canvas, candlePlot);
    _drawSelected(canvas, candlePlot, volPlot, rsiPlot);
    _drawDateLabels(canvas, datePlot);
    if (showVolume && volumeHeight > 0) _drawVolume(canvas, volPlot);
    if (rsiPlot != null) _drawRsi(canvas, rsiPlot);
    _drawYLabels(canvas, candlePlot);
  }

  void _drawFormationShade(Canvas canvas, Rect plot) {
    final n = bars.length;
    final hist = _historyPlot(plot);
    for (final r in patternRanges) {
      if (r.end < r.start) continue;
      final slot = hist.width / n;
      final x1 = _x(plot, r.start, n) - slot / 2;
      final x2 = _x(plot, r.end, n) + slot / 2;
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
    final hist = _historyPlot(plot);
    final slot = hist.width / n;
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

  /// Web big-chart Öngörü: son close → target_price noktaları sağa (gelecek dilim).
  void _drawForecasts(Canvas canvas, Rect plot) {
    if (forecasts.isEmpty || bars.isEmpty) return;
    final prices = _sortedForecastPrices(forecasts);
    if (prices.isEmpty) return;

    final n = bars.length;
    final last = bars.last.close;
    final path = Path()..moveTo(_x(plot, n - 1, n), _y(plot, last));
    for (var i = 0; i < prices.length; i++) {
      path.lineTo(_forecastX(plot, i, prices.length), _y(plot, prices[i]));
    }
    final paint = Paint()
      ..color = LotlotColors.danger.withValues(alpha: 0.88)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    _drawDashedPath(canvas, path, paint);
  }

  static List<double> _sortedForecastPrices(List<Map<String, dynamic>> raw) {
    const order = ['1d', '3d', '7d', '14d', '30d'];
    final items = <({String h, double price, num? end})>[];
    for (final f in raw) {
      final p = f['target_price'] ?? f['price'] ?? f['close'] ?? f['value'];
      if (p is! num) continue;
      final h = (f['horizon']?.toString() ?? '').toLowerCase();
      final et = f['end_time'];
      items.add((
        h: h,
        price: p.toDouble(),
        end: et is num ? et : null,
      ));
    }
    items.sort((a, b) {
      if (a.end != null && b.end != null) {
        return a.end!.compareTo(b.end!);
      }
      final ia = order.indexOf(a.h);
      final ib = order.indexOf(b.h);
      return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
    });
    return items.map((e) => e.price).take(8).toList();
  }

  static void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  void _drawVolume(Canvas canvas, Rect plot) {
    final vols = bars.map((b) => b.volume ?? 0.0).toList();
    final maxV = vols.fold<double>(0, math.max);
    if (maxV <= 0) return;
    final n = bars.length;
    final hist = _historyPlot(plot);
    final slot = hist.width / n;
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
    final bar = bars[selected];
    final cx = _x(candle, selected, n);
    final cy = _y(candle, bar.close);
    final up = bar.close >= bar.open;
    final tone = up ? LotlotColors.accent : LotlotColors.danger;

    final vPaint = Paint()
      ..color = LotlotColors.textPrimary.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    final bottom = volumeHeight > 0 ? vol.bottom : candle.bottom;
    canvas.drawLine(Offset(cx, candle.top), Offset(cx, bottom), vPaint);
    if (rsiPlot != null) {
      canvas.drawLine(
        Offset(cx, rsiPlot.top),
        Offset(cx, rsiPlot.bottom),
        vPaint,
      );
    }

    final hPaint = Paint()
      ..color = tone.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(candle.left, cy),
      Offset(candle.right, cy),
      hPaint,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      3.5,
      Paint()..color = tone,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: _priceLabel(bar.close),
      style: const TextStyle(
        color: LotlotColors.onAccent,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
    tp.layout();
    final tagTop = (cy - tp.height / 2).clamp(candle.top, candle.bottom - tp.height);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, tagTop - 2, _left - 4, tp.height + 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(bg, Paint()..color = tone);
    tp.paint(canvas, Offset(4, tagTop));
  }

  void _drawDateLabels(Canvas canvas, Rect plot) {
    if (bars.isEmpty || plot.height <= 0) return;
    final n = bars.length;
    final count = n <= 40 ? 3 : (n <= 120 ? 4 : 5);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < count; i++) {
      final idx = count == 1
          ? 0
          : ((n - 1) * i / (count - 1)).round().clamp(0, n - 1);
      final dt = DateTime.fromMillisecondsSinceEpoch(
        bars[idx].time * 1000,
        isUtc: true,
      ).toLocal();
      final label =
          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
      tp.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: LotlotColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      tp.layout();
      final x = _x(plot, idx, n) - tp.width / 2;
      final clampedX = x.clamp(plot.left, plot.right - tp.width);
      tp.paint(canvas, Offset(clampedX, plot.top + 2));
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

  /// Öngörü varken mumlar plot'un sol ~%72'sinde; sağ gelecek projeksiyon.
  static const _historyFrac = 0.72;

  Rect _historyPlot(Rect plot) {
    if (forecasts.isEmpty) return plot;
    return Rect.fromLTRB(
      plot.left,
      plot.top,
      plot.left + plot.width * _historyFrac,
      plot.bottom,
    );
  }

  double _x(Rect plot, int i, int n) {
    final hist = _historyPlot(plot);
    if (n <= 1) return hist.center.dx;
    final slot = hist.width / n;
    return hist.left + slot * (i + 0.5);
  }

  /// Gelecek dilimde i-inci öngörü noktası (0 = ilk horizon).
  double _forecastX(Rect plot, int i, int count) {
    final hist = _historyPlot(plot);
    final futureLeft = hist.right;
    final futureW = (plot.right - futureLeft).clamp(1.0, plot.width);
    final step = futureW / (count + 0.35);
    return futureLeft + step * (i + 0.65);
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
