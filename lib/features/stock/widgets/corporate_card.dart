import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Kurumsal — temettü / ortak / KAP teaser; boşsa shrink.
class CorporateCard extends StatelessWidget {
  const CorporateCard({super.key, required this.corporate});

  final Map<String, dynamic>? corporate;

  @override
  Widget build(BuildContext context) {
    if (corporate == null) return const SizedBox.shrink();

    final dividends = _maps(corporate!['dividends']);
    final holders = _maps(corporate!['major_holders']);
    final kap = _maps(corporate!['kap_news']);
    final capital = corporate!['paid_in_capital_fmt']?.toString();

    if (dividends.isEmpty &&
        holders.isEmpty &&
        kap.isEmpty &&
        (capital == null || capital.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kurumsal',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (capital != null && capital.isNotEmpty) ...[
                  Text(
                    'Ödenmiş sermaye: $capital',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                ],
                if (dividends.isNotEmpty) ...[
                  const Text(
                    'Temettü',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final d in dividends.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${d['date'] ?? '—'} · ${d['amount_fmt'] ?? d['amount'] ?? '—'}',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                if (holders.isNotEmpty) ...[
                  const Text(
                    'Ortaklık',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final h in holders.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${h['name'] ?? '—'}'
                        '${h['pct'] is num ? ' · %${(h['pct'] as num).toStringAsFixed(1)}' : ''}',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                if (kap.isNotEmpty) ...[
                  const Text(
                    'KAP',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final n in kap.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${n['date'] ?? ''} ${n['title'] ?? ''}'.trim(),
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
