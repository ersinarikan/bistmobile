import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chart_alerts_controller.dart';

/// Tek grafik alarm satırı — `status !== active` ise web plan-düşüş paused hali.
class ChartAlertRow extends StatelessWidget {
  const ChartAlertRow({
    super.key,
    required this.alert,
    this.onDelete,
    this.deleting = false,
  });

  final Map<String, dynamic> alert;
  final VoidCallback? onDelete;
  final bool deleting;

  static const pausedLabel = 'Duraklatıldı (plan limiti)';

  @override
  Widget build(BuildContext context) {
    final id = alert['id']?.toString() ??
        alert['alert_id']?.toString() ??
        alert['_id']?.toString() ??
        '';
    final symbol = alert['symbol']?.toString() ?? '—';
    final summary = alert['summary_tr']?.toString() ??
        alert['conditions_summary_tr']?.toString() ??
        alert['description']?.toString();
    final active = ChartAlertsController.isAlertActive(alert);

    return Opacity(
      opacity: active ? 1 : 0.65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LotlotColors.surface,
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: active
                          ? LotlotColors.textPrimary
                          : LotlotColors.textSecondary,
                    ),
                  ),
                  if (!active) ...[
                    const SizedBox(height: 4),
                    const Text(
                      pausedLabel,
                      style: TextStyle(
                        color: LotlotColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: const TextStyle(
                        color: LotlotColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sil',
              onPressed: id.isEmpty || deleting ? null : onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: LotlotColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
