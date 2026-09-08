import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class FutBoliaTypography {
  FutBoliaTypography._();

  static TextTheme textTheme() {
    final display = GoogleFonts.archivo(
      color: FutBoliaColors.ink,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );
    final body = GoogleFonts.manrope(
      color: FutBoliaColors.ink,
      fontWeight: FontWeight.w500,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40, height: 1.05),
      displayMedium: display.copyWith(fontSize: 32, height: 1.1),
      headlineLarge: display.copyWith(fontSize: 28, height: 1.15),
      headlineMedium: display.copyWith(fontSize: 22, height: 1.2),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: body.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.45),
      bodySmall: body.copyWith(
        fontSize: 12,
        height: 1.4,
        color: FutBoliaColors.inkMuted,
      ),
      labelLarge: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
