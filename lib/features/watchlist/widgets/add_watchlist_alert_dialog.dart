import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Web add-stock modal: Bildirim Açık/Kapalı. null = iptal.
Future<bool?> showAddWatchlistAlertDialog(BuildContext context) {
  var alertOn = true;
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: LotlotColors.surface,
            title: const Text('Listeye ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sinyal bildirimi (web ile aynı). Teslimat Premium + Hesap push ile.',
                  style: TextStyle(
                    color: LotlotColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Bildirim açık')),
                    ButtonSegment(value: false, label: Text('Kapalı')),
                  ],
                  selected: {alertOn},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setLocal(() => alertOn = s.first);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, alertOn),
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      );
    },
  );
}
