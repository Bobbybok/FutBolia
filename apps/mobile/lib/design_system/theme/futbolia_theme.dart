import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class FutBoliaTheme {
  FutBoliaTheme._();

  /// Light mode is disabled; kept as an alias so old calls stay dark.
  static ThemeData light() => dark();

  static ThemeData dark() {
    const onSurface = FutBoliaColors.inkDark;
    const line = FutBoliaColors.lineDark;
    final textTheme = FutBoliaTypography.textTheme(brightness: Brightness.dark);
    final radius = BorderRadius.circular(18);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: FutBoliaColors.lime,
        onPrimary: FutBoliaColors.ink,
        secondary: FutBoliaColors.pitch,
        onSecondary: Colors.white,
        tertiary: FutBoliaColors.clay,
        surface: FutBoliaColors.surfaceDark,
        onSurface: onSurface,
        error: FutBoliaColors.danger,
      ),
      scaffoldBackgroundColor: FutBoliaColors.surfaceDark,
      canvasColor: FutBoliaColors.surfaceDark,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.9)),
      dividerTheme: const DividerThemeData(color: line, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: FutBoliaColors.surfaceDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        foregroundColor: onSurface,
        iconTheme: const IconThemeData(color: onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FutBoliaColors.navDark,
        indicatorColor: FutBoliaColors.lime.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelLarge?.copyWith(
            fontSize: 11,
            color: selected
                ? FutBoliaColors.lime
                : onSurface.withValues(alpha: 0.7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? FutBoliaColors.lime
                : onSurface.withValues(alpha: 0.75),
            size: 22,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: onSurface.withValues(alpha: 0.55),
        indicatorColor: FutBoliaColors.lime,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleMedium,
        dividerColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FutBoliaColors.pitchDark,
        foregroundColor: Colors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FutBoliaColors.lime, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FutBoliaColors.pitch,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FutBoliaColors.lime,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FutBoliaColors.lime),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.55),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.7),
        ),
        prefixIconColor: onSurface.withValues(alpha: 0.85),
        suffixIconColor: onSurface.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: FutBoliaColors.lime, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: FutBoliaColors.cardDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FutBoliaColors.cardDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FutBoliaColors.cardDark,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: FutBoliaColors.cardDark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C2A24),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: FutBoliaColors.cardDark,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withValues(alpha: 0.85),
        textColor: onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FutBoliaColors.lime;
          }
          return onSurface.withValues(alpha: 0.55);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FutBoliaColors.lime.withValues(alpha: 0.35);
          }
          return line;
        }),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: FutBoliaColors.cardDark,
        headerBackgroundColor: FutBoliaColors.pitchDark,
        headerForegroundColor: Colors.white,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: FutBoliaColors.cardDark,
      ),
    );
  }
}
