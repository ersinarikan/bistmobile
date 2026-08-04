import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// Sunucudaki marka asset URL'leri — tek kaynak.
/// Launcher (home screen) ikonu store kuralı gereği yerelde kalır;
/// uygulama içi gösterimler buradan çekilir.
class BrandAssets {
  static const String iconTransparent =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-icon-transparent.png';
  static const String iconSquare =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-square.png';
  static const String wordmark =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-wordmark.png';
  static const String wide =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-wide.png';
  static const String pwaIcon512 =
      '${ApiConfig.baseUrl}/static/pwa/icon-512.png';
}

/// Lotlot logosu — CDN'den; değişince uygulamada yeniden build gerekmez.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width = 96,
    this.height = 88,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      BrandAssets.iconTransparent,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.analytics_outlined,
        size: height * 0.7,
        color: Theme.of(context).colorScheme.primary,
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Yatay wordmark (ikon + LOTLOT.NET) — AppBar / header.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 28,
    this.maxWidth = 160,
  });

  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      BrandAssets.wide,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Image.network(
        BrandAssets.wordmark,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'LOTLOT',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: height * 0.55,
                  color: LotlotColors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
              TextSpan(
                text: '.NET',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: height * 0.55,
                  color: LotlotColors.accent,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
            child: child,
          );
        }
        return SizedBox(
          width: maxWidth * 0.6,
          height: height,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: LotlotColors.accent,
              ),
            ),
          ),
        );
      },
    );
  }
}
