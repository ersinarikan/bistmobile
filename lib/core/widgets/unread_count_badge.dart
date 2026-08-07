import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// iOS uygulama ikonu tarzı kırmızı okunmamış sayı rozeti.
String formatUnreadBadgeCount(int count) {
  if (count <= 0) return '';
  if (count > 99) return '99+';
  return '$count';
}

/// [child] (ikon) üzerine sağ-üst kırmızı sayı; [count] ≤ 0 ise yalnız child.
class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({
    super.key,
    required this.count,
    required this.child,
  });

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = formatUnreadBadgeCount(count);
    return Badge(
      isLabelVisible: label.isNotEmpty,
      backgroundColor: LotlotColors.danger,
      textColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
      child: child,
    );
  }
}
