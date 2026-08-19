import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Web v654 `renderer.js` inactive-watchlist alert.
class WatchlistTierHoldBanner extends StatelessWidget {
  const WatchlistTierHoldBanner({super.key});

  static const copy =
      'Ücretsiz planda canlı izleme sınırlıdır. Fazlası silinmedi; '
      'plan yükseltince veya listeden hisse çıkarınca yeniden açılır.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: LotlotColors.border),
      ),
      child: const Text(
        copy,
        style: TextStyle(
          color: LotlotColors.textSecondary,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }
}
