import 'package:flutter/material.dart';

/// Web `static/css/brand.css` token’ları — brand-visual-parity.
/// Kaynak: lotlot.net / BIST `brand.css` (--brand-*).
class LotlotColors {
  static const Color backgroundDeep = Color(0xFF071610); // --brand-bg-0
  static const Color background = Color(0xFF0B2018); // --brand-bg-1
  static const Color backgroundMid = Color(0xFF0F2A20); // --brand-bg-2
  /// --brand-surface ≈ white@6% on bg-1
  static const Color surface = Color(0xFF1A2D26);
  /// --brand-surface-2 ≈ white@10% on bg-1
  static const Color surfaceElevated = Color(0xFF24362F);
  /// --brand-border ≈ white@12% on bg-1
  static const Color border = Color(0xFF283B34);
  static const Color accent = Color(0xFF19E38A); // --brand-accent
  static const Color accentMuted = Color(0xFF0FD37B); // --brand-accent-2
  static const Color textPrimary = Color(0xFFEAF7F1); // --brand-text
  static const Color textSecondary = Color(0xE0EAF7F1); // --brand-muted ~0.88
  static const Color danger = Color(0xFFFF4D4F); // --brand-danger
  static const Color warning = Color(0xFFFFC107); // --brand-warning
  static const Color onAccent = Color(0xFF071610);

  static const double radiusMd = 12; // --brand-radius-md
  static const double radiusLg = 16; // --brand-radius-lg
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: LotlotColors.background,
      colorScheme: const ColorScheme.dark(
        primary: LotlotColors.accent,
        onPrimary: LotlotColors.onAccent,
        secondary: LotlotColors.accentMuted,
        surface: LotlotColors.surface,
        onSurface: LotlotColors.textPrimary,
        error: LotlotColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LotlotColors.background,
        foregroundColor: LotlotColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LotlotColors.surfaceElevated,
        hintStyle: const TextStyle(color: LotlotColors.textSecondary),
        labelStyle: const TextStyle(color: LotlotColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          borderSide: const BorderSide(color: LotlotColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          borderSide: const BorderSide(color: LotlotColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          borderSide: const BorderSide(color: LotlotColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LotlotColors.accent,
          foregroundColor: LotlotColors.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LotlotColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: LotlotColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          ),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: LotlotColors.textPrimary,
        displayColor: LotlotColors.textPrimary,
      ),
    );
  }
}
