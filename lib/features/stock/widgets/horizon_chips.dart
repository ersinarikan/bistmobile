import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'formation_status.dart';

/// Ufuk seçici — web dashboard `1d..30d` ile aynı set.
class HorizonChips extends StatelessWidget {
  const HorizonChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.horizons = kFormationHorizons,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final List<String> horizons;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: horizons.map((h) {
        final isSelected = selected == h;
        return ChoiceChip(
          label: Text(h),
          selected: isSelected,
          onSelected: (_) => onSelected(h),
          selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
          labelStyle: TextStyle(
            color: isSelected ? LotlotColors.accent : LotlotColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isSelected ? LotlotColors.accent : LotlotColors.border,
          ),
          backgroundColor: LotlotColors.surface,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}
