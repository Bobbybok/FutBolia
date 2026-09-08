import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class FutBoliaTheme {
  FutBoliaTheme._();

  static ThemeData light() {
    final textTheme = FutBoliaTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: FutBoliaColors.pitch,
        onPrimary: Colors.white,
        secondary: FutBoliaColors.lime,
        onSecondary: FutBoliaColors.ink,
        tertiary: FutBoliaColors.clay,
        surface: FutBoliaColors.surface,
        onSurface: FutBoliaColors.ink,
        error: FutBoliaColors.danger,
      ),
      scaffoldBackgroundColor: FutBoliaColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        foregroundColor: FutBoliaColors.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FutBoliaColors.pitch,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FutBoliaColors.pitchDark,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: FutBoliaColors.line, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FutBoliaColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FutBoliaColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FutBoliaColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FutBoliaColors.pitch, width: 2),
        ),
      ),
    );
  }
}
