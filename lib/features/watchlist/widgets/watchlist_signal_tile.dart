import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lotlot_accent_card.dart';
import '../../auth/session_controller.dart';
import '../../stock/widgets/formation_status.dart';
import '../watchlist_controller.dart';
import 'watchlist_card_badges.dart';
import 'watchlist_detail_sheet.dart';

Color confidenceBarColor(String? type) {
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

String? actionPill(Map<String, dynamic>? signal) {
  if (signal == null) return null;
  final action = (signal['action'] ?? '').toString().trim().toUpperCase();
  if (action == 'AL' || action == 'SAT' || action == 'TUT') return action;
  return 'TUT';
}

bool isMutedActionable(Map<String, dynamic>? signal, {required bool isPaid}) {
  if (isPaid || signal == null) return false;
  final state = (signal['display_state'] ?? '').toString().toLowerCase();
  final pill = actionPill(signal);
  return (pill == 'AL' && state == 'actionable_bullish') ||
      (pill == 'SAT' && state == 'actionable_bearish');
}

bool isModelDegraded(Map<String, dynamic>? signal) {
  final state = (signal?['display_state'] ?? '').toString().toLowerCase();
  return state == 'model_degraded';
}

Color pillColorFor(String? pill, {required bool muted, required bool degraded}) {
  if (muted || degraded) return LotlotColors.warning;
  if (pill == 'SAT') return LotlotColors.danger;
  if (pill == 'AL') return LotlotColors.accent;
  return LotlotColors.textSecondary;
}

String? formatDeltaPct(dynamic raw) {
  if (raw is! num) return null;
  final pct = raw.abs() <= 1 ? raw * 100 : raw;
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(1)}%';
}

/// Web `updatePredictions` — 1G…30G hedef fiyat teaser.
List<String> horizonPriceTeasers(Map<String, dynamic>? pred) {
  final raw = pred?['predictions_by_horizon'] ?? pred?['predictions'];
  if (raw is! Map) return const [];
  const keys = ['1d', '3d', '7d', '14d', '30d'];
  final out = <String>[];
  for (final h in keys) {
    final v = raw[h];
    num? n;
    if (v is num) {
      n = v;
    } else if (v is Map) {
      final p = v['price'] ?? v['value'] ?? v['close'];
      if (p is num) n = p;
    }
    if (n == null) continue;
    final label = h.toUpperCase().replaceAll('D', 'G');
    out.add('$label: ${n.toStringAsFixed(2)}');
  }
  return out;
}

/// Web dashboard tek izleme kartı (Detay → sheet).
class WatchlistSignalTile extends StatelessWidget {
  const WatchlistSignalTile({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol']?.toString() ?? '';
    final name = item['name']?.toString();
    final active = item['active'] != false;
    final reason = item['disabled_reason']?.toString();
    final alertOn = item['alert_enabled'] == true;
    final session = context.watch<SessionController>();
    final wl = context.watch<WatchlistController>();
    final pred = symbol.isEmpty ? null : wl.predictionForSymbol(symbol);
    final analysis = symbol.isEmpty ? null : wl.patternForSymbol(symbol);
    final signal = pred != null ? wl.signalFor(pred) : null;
    final current = pred?['current_price'];
    final label = signal?['label']?.toString();
    final genel = signal?['genel_confidence_pct'];
    final barType = signal?['confidence_bar_type']?.toString();
    final delta = formatDeltaPct(signal?['delta_pct']);
    final pill = actionPill(signal);
    final muted = isMutedActionable(
      signal,
      isPaid: session.isPro || session.isPremium,
    );
    final degraded = isModelDegraded(signal);
    final note =
        signal?['note']?.toString() ?? signal?['summary_tr']?.toString();
    final barColor =
        degraded ? LotlotColors.warning : confidenceBarColor(barType);
    final pillColor = pillColorFor(pill, muted: muted, degraded: degraded);
    final teasers = horizonPriceTeasers(pred);

    final hz = wl.selectedHorizon;
    final hzChip = hz.toUpperCase().replaceAll('D', 'G');
    final badges = buildWatchlistPatternBadges(analysis);
    final mlRoot = analysis?['ml_unified'] is Map
        ? analysis!['ml_unified'] as Map
        : (pred?['ml_unified'] is Map ? pred!['ml_unified'] as Map : null);
    final ml = mlUnifiedForHorizon(mlRoot, hz);
    final bestKey = ml != null ? pickMlModelKey(ml) : null;
    final bestLabel = bestKey == null ? null : translateModelLabel(bestKey);
    final bestChip =
        (bestLabel == null || bestLabel == '-') ? null : bestLabel;
    final liquidity = analysis?['liquidity_warning'] == true;
    final evidence = analysis?['evidence_summary']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LotlotAccentCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                symbol,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  height: 1.2,
                                  color: active
                                      ? LotlotColors.textPrimary
                                      : LotlotColors.textSecondary,
                                ),
                              ),
                            ),
                            WatchlistMetaIcons(
                              liquidityWarning: liquidity,
                              evidenceSummary: evidence,
                            ),
                          ],
                        ),
                        if (name != null && name.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: LotlotColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        Text(
                          'Bildirim: ${alertOn ? 'Açık' : 'Kapalı'}',
                          style: const TextStyle(
                            color: LotlotColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current is num)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '₺${current.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1.2,
                          color: active
                              ? LotlotColors.textPrimary
                              : LotlotColors.textSecondary,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Kaldır',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: LotlotColors.danger,
                    ),
                    // mutating: çift DELETE + rate-limit fırtınasını kes.
                    onPressed: symbol.isEmpty ||
                            context.watch<WatchlistController>().mutating
                        ? null
                        : () => _remove(context, symbol),
                  ),
                ],
              ),
              if (teasers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  teasers.join('  '),
                  style: const TextStyle(
                    color: LotlotColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              WatchlistBadgeStrip(
                badges: badges,
                horizonChip: hzChip,
                selectedDelta: delta,
                bestModel: bestChip,
                emptyHint: analysis == null
                    ? null
                    : (badges.isEmpty ? 'Formasyon yok' : null),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pill != null)
                    Opacity(
                      opacity: muted ? 0.58 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: pillColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: pillColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          pill,
                          style: TextStyle(
                            color: pillColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label != null || delta != null)
                          Text(
                            [
                              if (label != null && label.isNotEmpty) label,
                              if (delta != null) 'Δ $delta',
                            ].join(' · '),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: muted || degraded
                                  ? LotlotColors.textSecondary
                                  : LotlotColors.textPrimary,
                            ),
                          ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: LotlotColors.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (genel is num) ...[
                const SizedBox(height: 8),
                const Text(
                  'Genel Sinyal Gücü',
                  style: TextStyle(
                    color: LotlotColors.textSecondary,
                    fontSize: 11,
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
                          value: (genel / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: LotlotColors.border,
                          color: muted
                              ? LotlotColors.textSecondary
                              : barColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '%${genel.round()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: muted
                            ? LotlotColors.textSecondary
                            : barColor,
                      ),
                    ),
                  ],
                ),
              ],
              if (!active && reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(
                    color: LotlotColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: symbol.isEmpty
                      ? null
                      : () => showWatchlistDetailSheet(
                            context,
                            symbol: symbol,
                            name: name,
                          ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('Detay'),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, String symbol) async {
    final ok = await context.read<WatchlistController>().removeSymbol(symbol);
    if (!context.mounted) return;
    if (!ok) {
      final err = context.read<WatchlistController>().lastError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }
}
