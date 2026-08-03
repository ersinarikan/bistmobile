import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Temel veri — null / unavailable → shrink; bank vs industrial.
class FundamentalsCard extends StatelessWidget {
  const FundamentalsCard({super.key, required this.fundamentals});

  final Map<String, dynamic>? fundamentals;

  @override
  Widget build(BuildContext context) {
    if (fundamentals == null) return const SizedBox.shrink();

    final balance = fundamentals!['balance_summary'];
    final bal = balance is Map
        ? Map<String, dynamic>.from(balance)
        : <String, dynamic>{};
    final mode = (fundamentals!['financial_profile'] ??
            bal['display_mode'] ??
            'industrial')
        .toString();
    final isBank = mode == 'bank';

    if (isBank) {
      if (bal['equity'] == null && bal['net_income_ttm'] == null) {
        return const SizedBox.shrink();
      }
    } else {
      if (bal['revenue_ttm'] == null && bal['net_income_ttm'] == null) {
        return const SizedBox.shrink();
      }
    }

    final sector = fundamentals!['sector_compare'];
    final sec = sector is Map
        ? Map<String, dynamic>.from(sector)
        : <String, dynamic>{};
    final foreign = fundamentals!['foreign_ownership'];
    final fo = foreign is Map
        ? Map<String, dynamic>.from(foreign)
        : <String, dynamic>{};
    final insights = fundamentals!['insights'];
    final ins = insights is Map
        ? Map<String, dynamic>.from(insights)
        : <String, dynamic>{};

    final rows = <_KV>[];
    if (isBank) {
      _add(rows, 'Faiz geliri (TTM)', bal['interest_income_ttm_fmt'] ??
          bal['revenue_ttm_fmt']);
      _add(rows, 'Net kâr (TTM)', bal['net_income_ttm_fmt']);
      _add(rows, 'Öz kaynak', bal['equity_fmt']);
      if (bal['roe_pct'] is num) {
        _add(rows, 'ROE', '%${(bal['roe_pct'] as num).toStringAsFixed(1)}');
      }
    } else {
      _add(rows, 'Gelir (TTM)', bal['revenue_ttm_fmt']);
      _add(rows, 'Net kâr (TTM)', bal['net_income_ttm_fmt']);
      if (bal['net_margin_pct'] is num) {
        _add(
          rows,
          'Net marj',
          '%${(bal['net_margin_pct'] as num).toStringAsFixed(1)}',
        );
      }
      if (bal['debt_to_equity'] is num) {
        _add(
          rows,
          'Borç / öz kaynak',
          (bal['debt_to_equity'] as num).toStringAsFixed(2),
        );
      }
    }

    if (sec['pb_ratio'] is num) {
      _add(rows, 'P/B', (sec['pb_ratio'] as num).toStringAsFixed(2));
    }
    if (!isBank && sec['pe_ratio'] is num) {
      _add(rows, 'P/E', (sec['pe_ratio'] as num).toStringAsFixed(2));
    }
    if (fo['ratio_pct'] is num) {
      _add(
        rows,
        'Yabancı payı',
        '%${(fo['ratio_pct'] as num).toStringAsFixed(1)}',
      );
    }

    final risks = ins['risks'] is List
        ? (ins['risks'] as List).whereType<String>().toList()
        : <String>[];
    final opps = ins['opportunities'] is List
        ? (ins['opportunities'] as List).whereType<String>().toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temel veri',
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
                for (final r in rows) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.k,
                          style: const TextStyle(
                            color: LotlotColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        r.v,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (risks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Riskler',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final t in risks.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '· $t',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
                if (opps.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Fırsatlar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final t in opps.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '· $t',
                        style: const TextStyle(
                          color: LotlotColors.textSecondary,
                          height: 1.35,
                          fontSize: 13,
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

  static void _add(List<_KV> rows, String k, Object? v) {
    if (v == null) return;
    final s = v.toString();
    if (s.isEmpty || s == 'null') return;
    rows.add(_KV(k, s));
  }
}

class _KV {
  const _KV(this.k, this.v);
  final String k;
  final String v;
}
