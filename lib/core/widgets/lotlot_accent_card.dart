import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// İzleme / Keşfet ortak kabuk — sol 5px accent + surface (web kart dili).
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
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: radius,
        border: const Border(
          left: BorderSide(color: LotlotColors.accent, width: 5),
          top: BorderSide(color: LotlotColors.border),
          right: BorderSide(color: LotlotColors.border),
          bottom: BorderSide(color: LotlotColors.border),
        ),
      ),
      child: child,
    );
    final card = onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: body,
            ),
          );
    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}
