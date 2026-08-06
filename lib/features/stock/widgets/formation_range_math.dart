import 'dart:math' as math;

/// Chart formation index math — spark + mum shade share `data_points` universe.
/// Pattern abs indices map to the tail of a series of length
/// `max(data_points, maxIx+1, displayCount)`.

const chartMlSources = {'ML_PREDICTOR', 'ENHANCED_ML', 'FINGPT'};

typedef SparkFormationRange = ({
  int start,
  int end,
  int normIdx,
  int startAbs,
  int endAbs,
  String source,
  String patternName,
  String signal,
});

typedef FormationShadeRange = ({
  int start,
  int end,
  bool bullish,
});

bool isFormationBullish(String? signal) {
  final s = (signal ?? '').toLowerCase();
  return s.contains('bull') || s == 'buy' || s == 'al';
}

/// Eligible chart formations (not ML/FINGPT; skip INVALID / empty STALE).
List<Map<String, dynamic>> eligibleChartFormations(
  Map<String, dynamic>? pattern,
) {
  final raw = pattern?['patterns'];
  if (raw is! List) return const [];

  final eligible = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final formation = Map<String, dynamic>.from(item);
    final source = (formation['source'] ?? '').toString().trim().toUpperCase();
    if (source.isEmpty || chartMlSources.contains(source)) continue;

    final recency =
        (formation['recency_bucket'] ?? '').toString().toUpperCase();
    final confidence = formation['confidence'];
    final confidenceValue = confidence is num ? confidence.toDouble() : 0.0;
    if (recency == 'INVALID' || (recency == 'STALE' && confidenceValue <= 0)) {
      continue;
    }

    final range = formation['range'];
    if (range is! Map ||
        range['start_index'] is! num ||
        range['end_index'] is! num) {
      continue;
    }
    eligible.add(formation);
  }
  return eligible;
}

int _maxAbsIndex(List<Map<String, dynamic>> eligible) {
  var maxIx = -1;
  for (final formation in eligible) {
    final range = formation['range'] as Map;
    maxIx = math.max(
      maxIx,
      math.max(
        (range['start_index'] as num).round(),
        (range['end_index'] as num).round(),
      ),
    );
  }
  return maxIx;
}

/// Index universe length shared by spark + candle shade.
int formationUniverseLength(
  Map<String, dynamic>? pattern,
  int displayCount,
) {
  final eligible = eligibleChartFormations(pattern);
  final maxIx = _maxAbsIndex(eligible);
  final apiPoints = pattern?['data_points'];
  final apiN = apiPoints is num && apiPoints > 0 ? apiPoints.toInt() : 0;
  return math.max(
    math.max(apiN, maxIx < 0 ? 0 : maxIx + 1),
    displayCount,
  );
}

int estimateSparkDisplayCount(Map<String, dynamic>? pattern, int barsLength) {
  if (barsLength <= 0) return 0;
  final eligible = eligibleChartFormations(pattern);
  var maxIx = -1;
  var minIx = 1 << 30;
  for (final formation in eligible) {
    final range = formation['range'] as Map;
    final start = (range['start_index'] as num).round();
    final end = (range['end_index'] as num).round();
    minIx = math.min(minIx, math.min(start, end));
    maxIx = math.max(maxIx, math.max(start, end));
  }

  final apiPoints = pattern?['data_points'];
  final apiN = apiPoints is num && apiPoints > 0 ? apiPoints.toInt() : 0;
  final totalPoints = math.max(apiN, maxIx < 0 ? 0 : maxIx + 1);
  final needed = maxIx < 0 ? 120 : math.max(120, totalPoints - minIx);
  return math.min(math.min(365, barsLength), needed);
}

List<SparkFormationRange> normalizeSparkFormationRanges(
  Map<String, dynamic>? pattern,
  int displayCount,
) {
  if (displayCount <= 0) return const [];
  final eligible = eligibleChartFormations(pattern);
  final offset = math.max(
    0,
    formationUniverseLength(pattern, displayCount) - displayCount,
  );
  final ranges = <SparkFormationRange>[];

  for (final formation in eligible) {
    final range = formation['range'] as Map;
    final startAbs = (range['start_index'] as num).round();
    final endAbs = (range['end_index'] as num).round();
    var start = startAbs - offset;
    var end = endAbs - offset;
    if (end < 0 || start >= displayCount) continue;
    start = start.clamp(0, displayCount - 1);
    end = end.clamp(0, displayCount - 1);
    if (end < start) continue;
    ranges.add((
      start: start,
      end: end,
      normIdx: ranges.length,
      startAbs: startAbs,
      endAbs: endAbs,
      source: (formation['source'] ?? '').toString(),
      patternName: (formation['pattern'] ?? '').toString(),
      signal: (formation['signal'] ?? '').toString(),
    ));
  }
  return ranges;
}

/// Local display ranges for candle formation shade (same offset as spark).
List<FormationShadeRange> localizeFormationShades(
  Map<String, dynamic>? pattern,
  int displayCount,
) {
  if (displayCount <= 0) return const [];
  final eligible = eligibleChartFormations(pattern);
  final offset = math.max(
    0,
    formationUniverseLength(pattern, displayCount) - displayCount,
  );
  final out = <FormationShadeRange>[];

  for (final formation in eligible) {
    final range = formation['range'] as Map;
    final startAbs = (range['start_index'] as num).round();
    final endAbs = (range['end_index'] as num).round();
    var start = startAbs - offset;
    var end = endAbs - offset;
    if (end < 0 || start >= displayCount) continue;
    start = start.clamp(0, displayCount - 1);
    end = end.clamp(0, displayCount - 1);
    if (end < start) continue;
    out.add((
      start: start,
      end: end,
      bullish: isFormationBullish(formation['signal']?.toString()),
    ));
  }
  return out;
}

int? normIdxForPatternItem(
  Map<String, dynamic>? pattern,
  Map<String, dynamic> item,
  int displayCount,
) {
  final itemRange = item['range'];
  if (itemRange is! Map ||
      itemRange['start_index'] is! num ||
      itemRange['end_index'] is! num) {
    return null;
  }
  final startAbs = (itemRange['start_index'] as num).round();
  final endAbs = (itemRange['end_index'] as num).round();
  final source = (item['source'] ?? '').toString();
  final patternName = (item['pattern'] ?? '').toString();
  final signal = (item['signal'] ?? '').toString();
  for (final range in normalizeSparkFormationRanges(pattern, displayCount)) {
    // Aynı mum aralığında birden fazla formasyon olabilir (ör. BASIC + ADVANCED).
    // Yalnız start/end eşleşirse listedeki iki satır aynı normIdx'i alır.
    if (range.startAbs == startAbs &&
        range.endAbs == endAbs &&
        range.source == source &&
        range.patternName == patternName &&
        range.signal == signal) {
      return range.normIdx;
    }
  }
  return null;
}
