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
  /// Stacked / hero — AppBar'da kullanma.
  static const String wide =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-wide.png';
  static const String pwaIcon512 =
      '${ApiConfig.baseUrl}/static/pwa/icon-512.png';
  /// AI yorum popup — web `lotlot-llm-icon-transparent.png`.
  static const String llmIcon =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-llm-icon-transparent.png';
  /// Boş izleme onboarding hero — web `lotlot-hero-transparent`.
  static const String heroTransparentWebp =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-hero-transparent.webp';
  static const String heroTransparentPng =
      '${ApiConfig.baseUrl}/static/img/brand/lotlot-hero-transparent.png';
}

/// Lotlot ikonu — CDN'den.
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

Widget _fallbackWordmarkText(double height) {
  return Text.rich(
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
  );
}

/// Web navbar parity: küçük ikon + yatay `lotlot-wordmark.png` (wide stacked değil).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 28,
    this.maxWidth = 168,
    this.showIcon = true,
  });

  final double height;
  final double maxWidth;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final iconSize = height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            BrandLogo(width: iconSize, height: iconSize),
            SizedBox(width: height * 0.28),
          ],
          Flexible(
            child: Image.network(
              BrandAssets.wordmark,
              height: height * 0.72,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => _fallbackWordmarkText(height),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: maxWidth * 0.45,
                  height: height * 0.72,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LotlotColors.accent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
