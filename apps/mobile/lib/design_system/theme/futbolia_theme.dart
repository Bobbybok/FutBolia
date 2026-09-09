import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class FutBoliaTheme {
  FutBoliaTheme._();

  static ThemeData light() {
    return _build(
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
      scaffoldBackground: FutBoliaColors.surface,
      onSurface: FutBoliaColors.ink,
      fill: FutBoliaColors.surfaceRaised,
      line: FutBoliaColors.line,
      outlinedForeground: FutBoliaColors.pitchDark,
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: FutBoliaColors.lime,
        onPrimary: FutBoliaColors.ink,
        secondary: FutBoliaColors.pitch,
        onSecondary: Colors.white,
        tertiary: FutBoliaColors.clay,
        surface: FutBoliaColors.surfaceDark,
        onSurface: FutBoliaColors.inkDark,
        error: FutBoliaColors.danger,
      ),
      scaffoldBackground: FutBoliaColors.surfaceDark,
      onSurface: FutBoliaColors.inkDark,
      fill: FutBoliaColors.surfaceRaisedDark,
      line: FutBoliaColors.lineDark,
      outlinedForeground: FutBoliaColors.lime,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color onSurface,
    required Color fill,
    required Color line,
    required Color outlinedForeground,
  }) {
    final textTheme = FutBoliaTypography.textTheme(brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        foregroundColor: onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: fill,
        indicatorColor: FutBoliaColors.pitch.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: onSurface.withValues(alpha: 0.62),
        indicatorColor: FutBoliaColors.pitch,
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
          foregroundColor: outlinedForeground,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: line, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FutBoliaColors.pitch, width: 2),
        ),
      ),
    );
  }
}
