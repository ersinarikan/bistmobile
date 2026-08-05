import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/features/stock/widgets/formation_range_math.dart';

Map<String, dynamic> _pattern({
  required int dataPoints,
  required List<Map<String, dynamic>> patterns,
}) {
  return {
    'data_points': dataPoints,
    'patterns': patterns,
  };
}

Map<String, dynamic> _formation({
  required String source,
  required int start,
  required int end,
  String signal = 'bullish',
  String? recency,
  num? confidence,
}) {
  final m = <String, dynamic>{
    'source': source,
    'signal': signal,
    'range': {'start_index': start, 'end_index': end},
  };
  if (recency != null) m['recency_bucket'] = recency;
  if (confidence != null) m['confidence'] = confidence;
  return m;
}

void main() {
  group('formation_range_math', () {
    test('FR1 data_points=400 display=60 last 10 → local 50–59', () {
      final pattern = _pattern(
        dataPoints: 400,
        patterns: [
          _formation(source: 'BASIC_TA', start: 390, end: 399),
        ],
      );
      final shades = localizeFormationShades(pattern, 60);
      expect(shades, hasLength(1));
      expect(shades.first.start, 50);
      expect(shades.first.end, 59);
    });

    test('FR2 uses data_points offset not barsLength', () {
      final pattern = _pattern(
        dataPoints: 400,
        patterns: [
          _formation(source: 'BASIC_TA', start: 390, end: 399),
        ],
      );
      const display = 60;
      const wrongBarsLength = 420;
      final shades = localizeFormationShades(pattern, display);
      // Wrong old candle math: abs - (barsLength - display) = 390 - 360 = 30
      final wrongStart = 390 - (wrongBarsLength - display);
      expect(shades.first.start, isNot(wrongStart));
      expect(shades.first.start, 50);
    });

    test('FR3 STALE confidence 0 and INVALID dropped', () {
      final pattern = _pattern(
        dataPoints: 100,
        patterns: [
          _formation(
            source: 'BASIC_TA',
            start: 90,
            end: 99,
            recency: 'STALE',
            confidence: 0,
          ),
          _formation(
            source: 'BASIC_TA',
            start: 80,
            end: 89,
            recency: 'INVALID',
            confidence: 1,
          ),
          _formation(
            source: 'BASIC_TA',
            start: 70,
            end: 79,
            signal: 'bearish',
          ),
        ],
      );
      final shades = localizeFormationShades(pattern, 60);
      expect(shades, hasLength(1));
      expect(shades.first.start, 30);
      expect(shades.first.end, 39);
      expect(shades.first.bullish, isFalse);
    });

    test('FR4 ML_PREDICTOR skipped', () {
      final pattern = _pattern(
        dataPoints: 100,
        patterns: [
          _formation(source: 'ML_PREDICTOR', start: 90, end: 99),
          _formation(source: 'FINGPT', start: 80, end: 89),
        ],
      );
      expect(localizeFormationShades(pattern, 60), isEmpty);
      expect(eligibleChartFormations(pattern), isEmpty);
    });

    test('FR5 bullish signal', () {
      final pattern = _pattern(
        dataPoints: 100,
        patterns: [
          _formation(source: 'VISUAL_YOLO', start: 90, end: 99, signal: 'BUY'),
        ],
      );
      final shades = localizeFormationShades(pattern, 40);
      expect(shades.single.bullish, isTrue);
    });

    test('FR6 spark normalize matches shade localize start/end', () {
      final pattern = _pattern(
        dataPoints: 400,
        patterns: [
          _formation(source: 'BASIC_TA', start: 350, end: 360, signal: 'al'),
          _formation(
            source: 'ADVANCED_TA',
            start: 370,
            end: 380,
            signal: 'bearish',
          ),
        ],
      );
      const display = 80;
      final spark = normalizeSparkFormationRanges(pattern, display);
      final shades = localizeFormationShades(pattern, display);
      expect(spark.length, shades.length);
      for (var i = 0; i < spark.length; i++) {
        expect(shades[i].start, spark[i].start);
        expect(shades[i].end, spark[i].end);
      }
    });
  });
}
