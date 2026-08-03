import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

String _tierLabel(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'very_high':
    case 'very-high':
      return 'Çok yüksek';
    case 'high':
      return 'Yüksek';
    case 'medium':
    case 'mid':
      return 'Orta';
    case 'low':
      return 'Düşük';
    case 'very_low':
    case 'very-low':
      return 'Çok düşük';
    default:
      return raw == null || raw.isEmpty ? '-' : raw.replaceAll('_', ' ');
  }
}

String _formatAvgVolume(num? v) {
  if (v == null) return '-';
  final n = v.toDouble();
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)} Mr';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)} Mn';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(0)} B';
  return n.toStringAsFixed(0);
}

String? _volatilityCopy(String? regime) {
  switch ((regime ?? '').toLowerCase()) {
    case 'high':
      return 'Yüksek volatilite — sinyal bandı geniş olabilir.';
    case 'low':
      return 'Düşük volatilite rejimi.';
    default:
      return null;
  }
}

/// Web detay modalı: hacim segmenti + ortalama hacim + volatilite.
class MarketMetaCard extends StatelessWidget {
  const MarketMetaCard({
    super.key,
    this.volumeTier,
    this.volatilityRegime,
  });

  final Map<String, dynamic>? volumeTier;
  final String? volatilityRegime;

  @override
  Widget build(BuildContext context) {
    final tier = volumeTier?['tier']?.toString();
    final avg = volumeTier?['avg_volume'];
    final lookback = volumeTier?['lookback_days'];
    final volCopy = _volatilityCopy(volatilityRegime);
    final hasTier = tier != null && tier.isNotEmpty;
    final hasAvg = avg is num;
    if (!hasTier && !hasAvg && volCopy == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LotlotColors.surface,
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hacim segmenti',
                    style: TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasTier)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: LotlotColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: LotlotColors.border),
                    ),
                    child: Text(
                      _tierLabel(tier),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasAvg) ...[
              const SizedBox(height: 6),
              Text(
                [
                  'Ort. hacim: ${_formatAvgVolume(avg)}',
                  if (lookback is num) '($lookback gün)',
                ].join(' '),
                style: const TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (volCopy != null) ...[
              const SizedBox(height: 6),
              Text(
                volCopy,
                style: TextStyle(
                  color: (volatilityRegime ?? '').toLowerCase() == 'high'
                      ? LotlotColors.warning
                      : LotlotColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
