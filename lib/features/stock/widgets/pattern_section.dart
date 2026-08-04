import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import 'formation_status.dart';
import 'horizon_chips.dart';

const _mlSources = {'ML_PREDICTOR', 'ENHANCED_ML', 'FINGPT'};

typedef SparkFormationRange = ({
  int start,
  int end,
  int normIdx,
  int startAbs,
  int endAbs,
});

List<Map<String, dynamic>> _eligibleSparkFormations(
  Map<String, dynamic>? pattern,
) {
  final raw = pattern?['patterns'];
  if (raw is! List) return const [];

  final eligible = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final formation = Map<String, dynamic>.from(item);
    final source = (formation['source'] ?? '').toString().trim().toUpperCase();
    if (source.isEmpty || _mlSources.contains(source)) continue;

    final recency = (formation['recency_bucket'] ?? '')
        .toString()
        .toUpperCase();
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

int estimateSparkDisplayCount(Map<String, dynamic>? pattern, int barsLength) {
  if (barsLength <= 0) return 0;
  final eligible = _eligibleSparkFormations(pattern);
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
  final eligible = _eligibleSparkFormations(pattern);
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

  final apiPoints = pattern?['data_points'];
  final apiN = apiPoints is num && apiPoints > 0 ? apiPoints.toInt() : 0;
  final totalPoints = math.max(
    math.max(apiN, maxIx < 0 ? 0 : maxIx + 1),
    displayCount,
  );
  final offset = math.max(0, totalPoints - displayCount);
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
    ));
  }
  return ranges;
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
  for (final range in normalizeSparkFormationRanges(pattern, displayCount)) {
    if (range.startAbs == startAbs && range.endAbs == endAbs) {
      return range.normIdx;
    }
  }
  return null;
}

const _sourceLabels = <String, String>{
  'VISUAL_YOLO': 'Görsel',
  'ADVANCED_TA': 'Teknik Analiz',
  'BASIC': 'Teknik Analiz',
  'BASIC_TA': 'Teknik Analiz',
  'FINGPT': 'Sezgisel',
};

String _directionLabel(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'bullish':
    case 'buy':
    case 'al':
      return 'Yükseliş';
    case 'bearish':
    case 'sell':
    case 'sat':
      return 'Düşüş';
    case 'neutral':
    case 'tut':
    case 'hold':
      return 'Nötr';
    default:
      return raw?.isNotEmpty == true ? raw!.replaceAll('_', ' ') : 'Nötr';
  }
}

Color _barColor(String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'buy':
      return LotlotColors.accent;
    case 'sell':
      return LotlotColors.danger;
    case 'warning':
      return LotlotColors.warning;
    default:
      return LotlotColors.textSecondary;
  }
}

/// Prod bazen `overall_signal` string (`BUY`), bazen nesne döner.
Map<String, dynamic>? _asOverallMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

String? _overallDirection(dynamic raw) {
  final map = _asOverallMap(raw);
  if (map != null) {
    return map['signal']?.toString() ?? map['direction']?.toString();
  }
  final s = raw?.toString().trim();
  if (s == null || s.isEmpty || s.startsWith('{')) return null;
  return s;
}

String? _overallReasoning(dynamic raw) {
  final map = _asOverallMap(raw);
  if (map == null) return null;
  final r = map['reasoning']?.toString().trim();
  return (r != null && r.isNotEmpty) ? r : null;
}

int? _overallStrengthPct(dynamic raw) {
  final map = _asOverallMap(raw);
  if (map == null) return null;
  final strength = map['strength'];
  if (strength is num) return strength.round().clamp(0, 100);
  final conf = map['confidence'];
  if (conf is num) {
    final v = conf <= 1 ? conf * 100 : conf;
    return v.round().clamp(0, 100);
  }
  return null;
}

class _NewsRow {
  const _NewsRow({required this.title, this.source, this.direction});
  final String title;
  final String? source;
  final String? direction;
}

/// Pattern özeti + ufuk + ML + Sezgisel + Formasyonlar — thin client (§16.1).
class PatternSection extends StatefulWidget {
  const PatternSection({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.pending,
    this.pattern,
    this.onFormationTap,
    this.selectedFormationNormIdx,
    this.formationDisplayCount = 120,
  });

  final bool isAuthenticated;
  final bool loading;
  final bool pending;
  final Map<String, dynamic>? pattern;
  final ValueChanged<int>? onFormationTap;
  final int? selectedFormationNormIdx;
  final int formationDisplayCount;

  @override
  State<PatternSection> createState() => _PatternSectionState();
}

class _PatternSectionState extends State<PatternSection> {
  String _horizon = '7d';

  @override
  void initState() {
    super.initState();
    _applyDefaultHorizon();
  }

  @override
  void didUpdateWidget(covariant PatternSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.pattern, oldWidget.pattern)) {
      _applyDefaultHorizon();
    }
  }

  void _applyDefaultHorizon() {
    final p = widget.pattern;
    if (p == null) return;
    final signals = p['signals_by_horizon'];
    final next = pickDefaultHorizon(signals is Map ? signals : null) ?? '7d';
    if (next != _horizon) {
      _horizon = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analiz özeti',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LotlotColors.surface,
              borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
              border: Border.all(color: LotlotColors.border),
            ),
            child: _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!widget.isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Formasyon ve sezgisel özet için giriş yapın.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(popOnSuccess: true),
                ),
              );
            },
            child: const Text('Giriş yap'),
          ),
        ],
      );
    }

    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LotlotColors.accent,
            ),
          ),
        ),
      );
    }

    if (widget.pending) {
      return const Text(
        'Analiz hazırlanıyor…',
        style: TextStyle(color: LotlotColors.textSecondary),
      );
    }

    final pattern = widget.pattern;
    if (pattern == null) {
      return const Text(
        'Analiz özeti şu an kullanılamıyor.',
        style: TextStyle(color: LotlotColors.textSecondary),
      );
    }

    final session = context.watch<SessionController>();
    final overallRaw = pattern['overall_signal'];
    final overallDir = _overallDirection(overallRaw);
    final overallReason = _overallReasoning(overallRaw);
    final overallStrength = _overallStrengthPct(overallRaw);

    final rawPatterns = pattern['patterns'];
    final allPatterns = rawPatterns is List
        ? rawPatterns.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];

    final newsContext = pattern['news_context'] is Map
        ? Map<String, dynamic>.from(pattern['news_context'] as Map)
        : null;

    final fingpt = allPatterns.cast<Map<String, dynamic>?>().firstWhere(
      (p) => (p?['source']?.toString() ?? '') == 'FINGPT',
      orElse: () => null,
    );

    final formations = sortFormations(allPatterns, excludeSources: _mlSources);

    final signalsRaw = pattern['signals_by_horizon'];
    final signalsMap = signalsRaw is Map ? signalsRaw : null;
    final signalRow = signalRowForHorizon(signalsMap, _horizon);
    final label = signalRow?['label']?.toString();
    final summary =
        signalRow?['summary_tr']?.toString() ??
        signalRow?['analysis_disclaimer_tr']?.toString() ??
        overallReason;

    final genelPct = signalRow?['genel_confidence_pct'];
    final barType = signalRow?['confidence_bar_type']?.toString();
    final strengthPct = genelPct is num
        ? genelPct.round().clamp(0, 100)
        : overallStrength;

    final mlRaw = pattern['ml_unified'];
    final mlMap = mlRaw is Map ? mlRaw : null;
    final mlHorizon = mlUnifiedForHorizon(mlMap, _horizon);

    final hasSezgisel =
        fingpt != null ||
        (newsContext != null &&
            ((newsContext['items'] is List &&
                    (newsContext['items'] as List).isNotEmpty) ||
                (newsContext['news_count'] is num &&
                    (newsContext['news_count'] as num) > 0)));

    final hasMl = mlMap != null && mlMap.isNotEmpty;
    final hasSignals = signalsMap != null && signalsMap.isNotEmpty;

    final hasContent =
        overallDir != null ||
        label != null ||
        summary != null ||
        formations.isNotEmpty ||
        hasSezgisel ||
        hasMl ||
        hasSignals;

    if (!hasContent) {
      if (!session.isPro) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ayrıntılı formasyonlar ve Sezgisel (haber) özeti Pro planda açılır.',
              style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  showSoftGateSheet(context, kind: SoftGateKind.pro),
              child: const Text('Planları gör'),
            ),
          ],
        );
      }
      return const Text(
        'Bu sembol için formasyon veya sezgisel özet bulunamadı.',
        style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
      );
    }

    // Free: sinyal özeti (watchlist parity); formasyon / sezgisel / ML kartı Pro.
    final proLayers = session.isPro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSignals || (proLayers && hasMl)) ...[
          HorizonChips(
            selected: _horizon,
            onSelected: (h) => setState(() => _horizon = h),
          ),
          const SizedBox(height: 12),
        ],
        if (label != null)
          Text(
            label,
            style: TextStyle(
              color: _barColor(barType),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          )
        else if (overallDir != null)
          Text(
            _directionLabel(overallDir),
            style: const TextStyle(
              color: LotlotColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        if (strengthPct != null) ...[
          const SizedBox(height: 8),
          const Text(
            'Genel Sinyal Gücü',
            style: TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strengthPct / 100,
                    minHeight: 6,
                    backgroundColor: LotlotColors.border,
                    color: _barColor(barType),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '%$strengthPct',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _barColor(barType),
                ),
              ),
            ],
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              color: LotlotColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        if (proLayers && (mlHorizon != null || hasMl)) ...[
          const SizedBox(height: 14),
          _MlSummaryCard(horizon: _horizon, horizonMl: mlHorizon),
        ],
        if (proLayers && hasSezgisel) ...[
          const SizedBox(height: 12),
          _SezgiselChip(fingpt: fingpt, newsContext: newsContext),
        ],
        if (proLayers && formations.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Formasyonlar',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          for (final item in formations.take(12))
            Builder(
              builder: (context) {
                final normIdx = normIdxForPatternItem(
                  pattern,
                  item,
                  widget.formationDisplayCount,
                );
                return _FormationRow(
                  item: item,
                  selected:
                      normIdx != null &&
                      normIdx == widget.selectedFormationNormIdx,
                  onTap: normIdx == null || widget.onFormationTap == null
                      ? null
                      : () => widget.onFormationTap!(normIdx),
                );
              },
            ),
        ] else if (proLayers && !hasSezgisel) ...[
          const SizedBox(height: 10),
          const Text(
            'Formasyon tespit edilemedi.',
            style: TextStyle(color: LotlotColors.textSecondary, fontSize: 13),
          ),
        ],
        if (!proLayers) ...[
          const SizedBox(height: 14),
          const Text(
            'Formasyonlar, Sezgisel ve ML tahmin özeti Pro planda açılır.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => showSoftGateSheet(context, kind: SoftGateKind.pro),
            child: const Text('Planları gör'),
          ),
        ],
      ],
    );
  }
}

class _MlSummaryCard extends StatelessWidget {
  const _MlSummaryCard({required this.horizon, this.horizonMl});

  final String horizon;
  final Map<String, dynamic>? horizonMl;

  /// Web `_detailDeltaPresentation` — sol çerçeve rengi.
  static Color _deltaBorderColor(num? deltaPct) {
    if (deltaPct == null) return LotlotColors.border;
    if (deltaPct > 0) return LotlotColors.accent;
    if (deltaPct < 0) return LotlotColors.danger;
    return LotlotColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final hLabel = horizon.toUpperCase().replaceAll('D', 'G');

    if (horizonMl == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LotlotColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: LotlotColors.border, width: 3),
            top: BorderSide(color: LotlotColors.border),
            right: BorderSide(color: LotlotColors.border),
            bottom: BorderSide(color: LotlotColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tahmin özeti · $hLabel',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bu ufuk için ML tahmin bilgisi yok.',
              style: TextStyle(color: LotlotColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final key = pickMlModelKey(horizonMl!);
    final pick = key != null && horizonMl![key] is Map
        ? Map<String, dynamic>.from(horizonMl![key] as Map)
        : null;
    final price = pick?['price'];
    final delta = pick?['delta_pct'];
    final conf = pick?['confidence'] ?? pick?['reliability'];
    final confPct = conf is num
        ? (conf <= 1 ? conf * 100 : conf).round().clamp(0, 100)
        : null;
    // Web: usedDeltaPct as fraction; border from sign of delta
    final deltaFrac = delta is num ? delta.toDouble() : null;
    final deltaPct = deltaFrac != null
        ? (deltaFrac.abs() <= 1 ? deltaFrac * 100 : deltaFrac)
        : null;
    final borderColor = _deltaBorderColor(
      deltaFrac == null
          ? null
          : (deltaFrac.abs() <= 1 ? deltaFrac : deltaFrac / 100),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LotlotColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
          top: const BorderSide(color: LotlotColors.border),
          right: const BorderSide(color: LotlotColors.border),
          bottom: const BorderSide(color: LotlotColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tahmin özeti · $hLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (key != null) _MiniBadge(translateModelLabel(key)),
            ],
          ),
          if (price is num || deltaPct != null || confPct != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (price is num) 'Hedef: ${price.toStringAsFixed(2)}',
                if (deltaPct != null)
                  'Δ %${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}',
                if (confPct != null) 'Model %$confPct',
              ].join(' · '),
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'Model özeti mevcut.',
              style: TextStyle(color: LotlotColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SezgiselChip extends StatelessWidget {
  const _SezgiselChip({this.fingpt, this.newsContext});

  final Map<String, dynamic>? fingpt;
  final Map<String, dynamic>? newsContext;

  @override
  Widget build(BuildContext context) {
    final dir =
        fingpt?['signal']?.toString() ??
        newsContext?['display_direction']?.toString() ??
        'neutral';
    final conf = fingpt?['confidence'] ?? newsContext?['confidence'];
    final count = fingpt?['news_count'] ?? newsContext?['news_count'];
    final confPct = conf is num
        ? (conf <= 1 ? conf * 100 : conf).round()
        : null;
    final label = [
      'Sezgisel',
      _directionLabel(dir),
      if (confPct != null) '(%$confPct)',
      if (count is num && count > 0) '· $count haber',
    ].join(' ');

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LotlotColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: LotlotColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: LotlotColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final rows = <_NewsRow>[];
    final items = newsContext?['items'];
    if (items is List) {
      for (final it in items.take(8)) {
        if (it is! Map) continue;
        final t = it['title']?.toString();
        if (t == null || t.isEmpty) continue;
        rows.add(
          _NewsRow(
            title: t,
            source: it['source']?.toString(),
            direction: it['direction']?.toString(),
          ),
        );
      }
    }
    if (rows.isEmpty) {
      final ni = fingpt?['news_items'];
      if (ni is List) {
        for (final t in ni.take(8)) {
          final s = t?.toString();
          if (s != null && s.isNotEmpty) {
            rows.add(_NewsRow(title: s));
          }
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LotlotColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LotlotColors.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sezgisel Analiz',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: LotlotColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'İlgili haberler',
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text(
                  'Haber özeti şu an yok.',
                  style: TextStyle(color: LotlotColors.textSecondary),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      final meta = [
                        if (row.source != null && row.source!.isNotEmpty)
                          row.source!,
                        if (row.direction != null && row.direction!.isNotEmpty)
                          _directionLabel(row.direction),
                      ].join(' · ');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: const TextStyle(height: 1.4, fontSize: 14),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: const TextStyle(
                                color: LotlotColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Yatırım tavsiyesi değildir. Veri analizidir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormationRow extends StatelessWidget {
  const _FormationRow({required this.item, required this.selected, this.onTap});

  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback? onTap;

  bool get _visualOk {
    final conf = item['confirmation_sources'];
    if (conf is List) {
      return conf.any((e) => e?.toString().toUpperCase() == 'VISUAL_YOLO');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final name = item['pattern']?.toString() ?? 'Formasyon';
    final signal = item['signal']?.toString();
    final source = item['source']?.toString() ?? '';
    final sourceLabel = _sourceLabels[source] ?? source;
    final status = formationStatus(item);
    final effectHint = item['effect_hint_tr']?.toString();
    final effectLabel = item['effect_label']?.toString();
    final conf = item['confidence'];
    final confPct = conf is num
        ? (conf <= 1 ? conf * 100 : conf).round()
        : null;
    final isVisual = source == 'VISUAL_YOLO';
    final signalLabel = signal != null && signal.isNotEmpty
        ? _directionLabel(signal)
        : null;

    final effectState = (item['effect_state']?.toString() ?? '').toLowerCase();
    final showEffectLabel =
        effectLabel != null &&
        effectLabel.isNotEmpty &&
        !const {
          'forming',
          'armed',
          'triggered_active',
          'retest_active',
        }.contains(effectState) &&
        effectLabel.toLowerCase() != status.key;
    final secondary = <String>[];
    if (effectHint != null &&
        effectHint.isNotEmpty &&
        effectHint.toLowerCase() != status.key) {
      secondary.add(effectHint);
    } else if (showEffectLabel) {
      secondary.add(effectLabel);
    }

    final title = signalLabel == null ? name : '$name · $signalLabel';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selected
            ? LotlotColors.warning.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (confPct != null)
                      Text(
                        '%$confPct',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniBadge(status.key),
                    if (sourceLabel.isNotEmpty && !isVisual)
                      _MiniBadge(sourceLabel),
                    if (isVisual) const _MiniBadge('Görsel'),
                    if (_visualOk && !isVisual)
                      const Tooltip(
                        message:
                            'Bu formasyon görsel analiz ile de doğrulandı.',
                        child: _MiniBadge('görsel onay'),
                      ),
                  ],
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondary.join(' · '),
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: LotlotColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
