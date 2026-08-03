import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import '../../stock/stock_detail_screen.dart';
import '../watchlist_controller.dart';

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
  // Web: resolveCardPillAction — yalnızca backend `action` (AL|SAT|TUT).
  final action = (signal['action'] ?? '').toString().trim().toUpperCase();
  if (action == 'AL' || action == 'SAT' || action == 'TUT') return action;
  return 'TUT';
}

/// Web: mute yalnızca ücretsiz — `!(APP_IS_PRO || APP_IS_PREMIUM)`.
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

/// Web dashboard izleme kartına yakın sinyal satırı.
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
    final note = signal?['note']?.toString() ??
        signal?['summary_tr']?.toString();
    final barColor = degraded
        ? LotlotColors.warning
        : confidenceBarColor(barType);
    final pillColor = pillColorFor(pill, muted: muted, degraded: degraded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          onTap: symbol.isEmpty
              ? null
              : () => openStockDetail(context, symbol: symbol, name: name),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
              border: Border.all(color: LotlotColors.border),
            ),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: active
                                        ? LotlotColors.textPrimary
                                        : LotlotColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (pill != null) ...[
                                const SizedBox(width: 8),
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
                              ],
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
                        ],
                      ),
                    ),
                    if (current is num)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: Text(
                          current.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: alertOn
                          ? 'Sinyal uyarısını kapat'
                          : 'Sinyal uyarısını aç',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        alertOn
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: alertOn
                            ? LotlotColors.accent
                            : LotlotColors.textSecondary,
                      ),
                      onPressed: symbol.isEmpty || wl.mutating
                          ? null
                          : () => _toggleAlert(context, wl, session, symbol, alertOn),
                    ),
                    IconButton(
                      tooltip: 'Kaldır',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: LotlotColors.danger,
                      ),
                      onPressed: symbol.isEmpty
                          ? null
                          : () => _remove(context, symbol),
                    ),
                  ],
                ),
                if (label != null || delta != null) ...[
                  const SizedBox(height: 6),
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
                ],
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: degraded
                          ? LotlotColors.warning
                          : LotlotColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
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
                            value: genel.toDouble().clamp(0, 100) / 100.0,
                            minHeight: 5,
                            color: muted
                                ? LotlotColors.textSecondary
                                : barColor,
                            backgroundColor: LotlotColors.border,
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
                if (!active && reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pasif ($reason)',
                    style: const TextStyle(
                      color: LotlotColors.warning,
                      fontSize: 12,
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

  Future<void> _toggleAlert(
    BuildContext context,
    WatchlistController wl,
    SessionController session,
    String symbol,
    bool alertOn,
  ) async {
    if (!session.isPremium) {
      await showSoftGateSheet(context, kind: SoftGateKind.premium);
      return;
    }
    final turningOn = !alertOn;
    final ok = await wl.setAlertEnabled(symbol, !alertOn);
    if (!context.mounted) return;
    if (!ok) {
      final apiErr = wl.lastApiError;
      if (apiErr != null && tryShowSoftGateForApiError(context, apiErr)) {
        return;
      }
      if (wl.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wl.lastError!)),
        );
      }
      return;
    }
    if (turningOn && !session.pushNotificationsOn) {
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
