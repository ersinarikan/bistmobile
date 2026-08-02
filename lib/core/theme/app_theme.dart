import 'package:flutter/material.dart';

/// LOTLOT.NET koyu yeşil + neon yeşil marka paleti.
class LotlotColors {
  static const Color background = Color(0xFF0B1F14);
  static const Color surface = Color(0xFF12281B);
  static const Color surfaceElevated = Color(0xFF1A3324);
  static const Color accent = Color(0xFF39FF14);
  static const Color accentMuted = Color(0xFF2BC40F);
  static const Color textPrimary = Color(0xFFF5F7F5);
  static const Color textSecondary = Color(0xFFA8B5AB);
  static const Color border = Color(0xFF2A4534);
  static const Color danger = Color(0xFFFF6B6B);
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
        onPrimary: Color(0xFF041008),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LotlotColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LotlotColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LotlotColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LotlotColors.accent,
          foregroundColor: const Color(0xFF041008),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
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
