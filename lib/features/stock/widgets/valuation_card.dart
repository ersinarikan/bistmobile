import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Adil Değer — fair_value yoksa shrink.
class ValuationCard extends StatelessWidget {
  const ValuationCard({super.key, required this.valuation});

  final Map<String, dynamic>? valuation;

  @override
  Widget build(BuildContext context) {
    if (valuation == null) return const SizedBox.shrink();
    final fv = valuation!['fair_value'];
    if (fv == null) return const SizedBox.shrink();

    final current = valuation!['current_price'];
    final label = valuation!['valuation_label_tr']?.toString() ??
        valuation!['valuation_label']?.toString();
    final premium = valuation!['premium_pct'];
    final analystMean = valuation!['analyst_mean'];
    final analystCount = valuation!['analyst_count'];
    final key = valuation!['valuation_label']?.toString();

    Color barColor = LotlotColors.accentMuted;
    if (key == 'discount') barColor = LotlotColors.accent;
    if (key == 'premium') barColor = LotlotColors.warning;
    if (key == 'fair') barColor = LotlotColors.textSecondary;

    // Guide §17.2: fair band ±%5; marker travels on ±20% visual span.
    double pos = 0.5;
    if (premium is num) {
      pos = ((premium.toDouble() + 20) / 40).clamp(0.05, 0.95);
    } else if (key == 'discount') {
      pos = 0.2;
    } else if (key == 'premium') {
      pos = 0.8;
    }

    return _StockSection(
      title: 'Adil Değer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmt(fv),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: LotlotColors.accent,
                  ),
                ),
              ),
              if (label != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 6),
            Text(
              'Güncel: ${_fmt(current)}',
              style: const TextStyle(color: LotlotColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          LotlotColors.accent,
                          LotlotColors.textSecondary,
                          LotlotColors.warning,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * pos - 6,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: LotlotColors.textPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: barColor, width: 2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Güncel fiyat, analist hedefleri ve sektör çarpanlarından '
            'türetilen referans değerle karşılaştırılır. Renkli bar '
            'iskontolu / makul / primli bölgeyi gösterir.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LotlotColors.textSecondary,
                  height: 1.4,
                ),
          ),
          if (analystMean != null) ...[
            const SizedBox(height: 8),
            Text(
              'Analist ort.: ${_fmt(analystMean)}'
              '${analystCount != null ? ' ($analystCount analist)' : ''}',
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(Object? v) {
    if (v is num) {
      final d = v.toDouble();
      if (d >= 100) return d.toStringAsFixed(1);
      return d.toStringAsFixed(2);
    }
    return v?.toString() ?? '—';
  }
}

class _StockSection extends StatelessWidget {
  const _StockSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
            child: child,
          ),
        ],
      ),
    );
  }
}
