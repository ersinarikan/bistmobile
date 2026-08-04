import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../stock/widgets/formation_status.dart';

const _cardExcludeSources = {'ML_PREDICTOR', 'ENHANCED_ML'};
const _maxCardBadges = 4;

/// Web `renderer._buildPatternBadges` + pred chip satırı için kart rozet modeli.
class WatchlistCardBadge {
  const WatchlistCardBadge({
    required this.label,
    required this.color,
    this.tooltip,
  });

  final String label;
  final Color color;
  final String? tooltip;
}

String translateSezgiselShort(String? signal) {
  final u = (signal ?? '').trim().toUpperCase();
  final l = (signal ?? '').trim().toLowerCase();
  if (u == 'BULLISH' || l == 'bullish') return 'Yükseliş';
  if (u == 'BEARISH' || l == 'bearish') return 'Düşüş';
  return 'Nötr';
}

Color _signalBadgeColor(String? signal) {
  final u = (signal ?? '').toUpperCase();
  final l = (signal ?? '').toLowerCase();
  if (u == 'BULLISH' || l == 'bullish') return LotlotColors.accent;
  if (u == 'BEARISH' || l == 'bearish') return LotlotColors.danger;
  return LotlotColors.textSecondary;
}

String _cardStatusSuffix(Map<String, dynamic> p) {
  final effect = (p['effect_state']?.toString() ?? '').toLowerCase();
  final rec = (p['recency_bucket']?.toString() ?? '').toUpperCase();
  final ageRaw = p['age_bars'];
  final age = ageRaw is num ? ageRaw.round().clamp(0, 9999) : null;

  if (p['valid'] == false || rec == 'INVALID') return ' (bozuldu)';
  if (p['played_out'] == true) return ' (tamamlandı)';
  if (effect == 'triggered_active') return ' (etkisi sürüyor)';
  if (effect == 'retest_active') return ' (retest)';
  if (effect == 'armed') return ' (eşikte)';
  if (effect == 'forming') return ' (oluşuyor)';
  if (rec == 'RECENT') {
    if (age != null && age > 0) return ' (yakın • $age bar)';
    return ' (yakın)';
  }
  if (rec == 'STALE') return ' (geçmiş)';
  if (rec == 'ACTIVE') return ' (güncel)';
  final st = formationStatus(p);
  if (st.key.isNotEmpty && st.key != 'tespit') return ' (${st.key})';
  return '';
}

int _rankPattern(Map<String, dynamic> p) {
  final effect = (p['effect_state']?.toString() ?? '').toLowerCase();
  final rec = (p['recency_bucket']?.toString() ?? '').toUpperCase();
  if (effect == 'triggered_active') return 0;
  if (effect == 'retest_active') return 1;
  if (effect == 'armed') return 2;
  if (effect == 'forming') return 3;
  if (effect == 'observed') return 4;
  if (effect == 'exhausted' || p['played_out'] == true) return 5;
  if (effect == 'invalidated' || p['valid'] == false || rec == 'INVALID') {
    return 6;
  }
  if (rec == 'ACTIVE') return 0;
  if (rec == 'RECENT') return 1;
  if (rec == 'STALE') return 2;
  return 7;
}

/// Web kart `#patt-*` rozet listesi (max 4 + overflow ayrı).
List<WatchlistCardBadge> buildWatchlistPatternBadges(
  Map<String, dynamic>? analysis,
) {
  if (analysis == null) return const [];

  final raw = analysis['patterns'];
  final patterns = raw is List
      ? raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  final filtered = patterns.where((p) {
    final src = (p['source']?.toString() ?? '').toUpperCase();
    if (_cardExcludeSources.contains(src)) return false;
    final rec = (p['recency_bucket']?.toString() ?? '').toUpperCase();
    final conf = p['confidence'];
    final confN = conf is num ? conf.toDouble() : 0.0;
    if (confN <= 0 && (rec == 'STALE' || rec == 'INVALID')) return false;
    return true;
  }).toList();

  final fingpt = filtered
      .where((p) => (p['source']?.toString() ?? '').toUpperCase() == 'FINGPT')
      .toList()
    ..sort((a, b) {
      final ca = a['confidence'] is num ? (a['confidence'] as num) : 0;
      final cb = b['confidence'] is num ? (b['confidence'] as num) : 0;
      return cb.compareTo(ca);
    });
  final others = filtered
      .where((p) => (p['source']?.toString() ?? '').toUpperCase() != 'FINGPT')
      .toList()
    ..sort((a, b) {
      final rd = _rankPattern(a).compareTo(_rankPattern(b));
      if (rd != 0) return rd;
      final ca = a['confidence'] is num ? (a['confidence'] as num) : 0;
      final cb = b['confidence'] is num ? (b['confidence'] as num) : 0;
      return cb.compareTo(ca);
    });

  final ordered = [...fingpt, ...others];
  final out = <WatchlistCardBadge>[];

  final ctx = analysis['news_context'];
  final ctxMap = ctx is Map ? Map<String, dynamic>.from(ctx) : null;
  final ctxItems = ctxMap?['items'];
  final hasCtxItems = ctxItems is List && ctxItems.isNotEmpty;
  if (fingpt.isEmpty && hasCtxItems && ctxMap != null) {
    final dir = ctxMap['display_direction']?.toString() ?? 'neutral';
    out.add(
      WatchlistCardBadge(
        label: 'Sezgisel (${translateSezgiselShort(dir)})',
        color: _signalBadgeColor(dir),
        tooltip: 'Sezgisel haber eşleşmesi',
      ),
    );
  }

  for (final p in ordered) {
    final src = (p['source']?.toString() ?? '').toUpperCase();
    final signal = p['signal']?.toString();
    String name;
    if (src == 'FINGPT') {
      name = 'Sezgisel (${translateSezgiselShort(signal)})';
    } else {
      name = (p['pattern']?.toString() ?? 'Formasyon').replaceAll('_', ' ');
    }
    final suffix = _cardStatusSuffix(p);
    final conf = p['confidence'];
    final confPct = conf is num
        ? ((conf <= 1 ? conf * 100 : conf).round().clamp(0, 100))
        : null;
    out.add(
      WatchlistCardBadge(
        label: '$name$suffix',
        color: _signalBadgeColor(signal),
        tooltip: confPct != null ? '%$confPct' : null,
      ),
    );
  }

  return out;
}

class WatchlistBadgeStrip extends StatelessWidget {
  const WatchlistBadgeStrip({
    super.key,
    required this.badges,
    this.horizonChip,
    this.selectedDelta,
    this.bestModel,
    this.emptyHint,
  });

  final List<WatchlistCardBadge> badges;
  final String? horizonChip;
  final String? selectedDelta;
  final String? bestModel;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final shown = badges.take(_maxCardBadges).toList();
    final remaining = badges.length - shown.length;
    final chips = <Widget>[];

    if (horizonChip != null && horizonChip!.isNotEmpty) {
      chips.add(_Chip(
        label: horizonChip!,
        color: LotlotColors.accent,
        bold: true,
      ));
    }
    if (selectedDelta != null && selectedDelta!.isNotEmpty) {
      chips.add(
        Text(
          'Seçili ufuk: $selectedDelta',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selectedDelta!.startsWith('-')
                ? LotlotColors.danger
                : LotlotColors.accent,
          ),
        ),
      );
    }
    if (bestModel != null && bestModel!.isNotEmpty) {
      chips.add(_Chip(
        label: bestModel!,
        color: bestModel!.contains('Gelişmiş')
            ? LotlotColors.warning
            : const Color(0xFF38BDF8),
      ));
    }
    for (final b in shown) {
      chips.add(_Chip(label: b.label, color: b.color));
    }
    if (remaining > 0) {
      chips.add(_Chip(
        label: '+$remaining',
        color: LotlotColors.textSecondary,
      ));
    }

    if (chips.isEmpty) {
      if (emptyHint == null) return const SizedBox.shrink();
      return Text(
        emptyHint!,
        style: const TextStyle(
          color: LotlotColors.textSecondary,
          fontSize: 11,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    this.bold = false,
  });

  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Likidite / kanıt ikonları (web header icons).
class WatchlistMetaIcons extends StatelessWidget {
  const WatchlistMetaIcons({
    super.key,
    this.liquidityWarning = false,
    this.evidenceSummary,
  });

  final bool liquidityWarning;
  final String? evidenceSummary;

  @override
  Widget build(BuildContext context) {
    if (!liquidityWarning &&
        (evidenceSummary == null || evidenceSummary!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (liquidityWarning)
          IconButton(
            tooltip:
                'İşlem hacmi ortalamaya göre düşük. Giriş/çıkış spread’i yüksek olabilir.',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.bar_chart,
              size: 18,
              color: LotlotColors.warning,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'İşlem hacmi ortalamaya göre düşük. Giriş/çıkış spread’i yüksek olabilir.',
                  ),
                ),
              );
            },
          ),
        if (evidenceSummary != null && evidenceSummary!.trim().isNotEmpty)
          IconButton(
            tooltip: 'Kanıt: ${evidenceSummary!.trim()}',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.info_outline,
              size: 18,
              color: LotlotColors.textSecondary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kanıt: ${evidenceSummary!.trim()}'),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
          ),
      ],
    );
  }
}
