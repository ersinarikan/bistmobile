import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// İzleme / Keşfet ortak kabuk — sol 5px accent + surface (web kart dili).
///
/// Non-uniform [Border] + [borderRadius] Flutter’da boyama hatası verir
/// (`A borderRadius can only be given on borders with uniform colors`);
/// sol şerit ayrı widget ile çizilir.
class LotlotAccentCard extends StatelessWidget {
  const LotlotAccentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LotlotColors.radiusMd);
    final body = Material(
      color: LotlotColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: LotlotColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: LotlotColors.accent,
              child: SizedBox(width: 5),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
    final card = onTap == null
        ? body
        : InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: body,
          );
    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}
