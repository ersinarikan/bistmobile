import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Web v655 `renderer.js` `_watchlistLiveLimitNote`.
class WatchlistTierHoldBanner extends StatelessWidget {
  const WatchlistTierHoldBanner({super.key, this.limit});

  final int? limit;

  static String copyForLimit(int? limit) {
    final n = (limit != null && limit > 0) ? limit : 10;
    return 'Canlı izleme $n hisse. Diğerleri listenizde duruyor — '
        'yer açın veya planı yükseltin.';
  }

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
      child: Text(
        copyForLimit(limit),
        style: const TextStyle(
          color: LotlotColors.textSecondary,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }
}
