import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Web `#firstStockGuideModal` — liste 0→1 sonrası.
Future<void> showFirstStockGuideDialog(
  BuildContext context, {
  required String horizonLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LotlotColors.surfaceElevated,
      title: const Row(
        children: [
          Icon(Icons.route, color: LotlotColors.accent, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'İlk bakılacaklar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideLine(
            rich: TextSpan(
              children: [
                TextSpan(
                  text: horizonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' seçili ufuktaki hareketi gösterir.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _GuideLine(
            rich: TextSpan(
              children: [
                TextSpan(
                  text: 'Genel Sinyal Gücü',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' kanıtların toplamını özetler.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _GuideLine(
            rich: TextSpan(
              children: [
                TextSpan(
                  text: 'Detay',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' butonu nedenleri ve grafiği açar.'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
}

String horizonShortLabel(String horizon) =>
    horizon.toUpperCase().replaceAll('D', 'G');

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.rich});

  final InlineSpan rich;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      rich,
      style: const TextStyle(
        color: LotlotColors.textPrimary,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }
}
