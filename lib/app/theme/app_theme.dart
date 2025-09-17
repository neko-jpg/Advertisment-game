import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData darkTheme() {
    final baseTheme = ThemeData(brightness: Brightness.dark);
    final baseTextTheme = GoogleFonts.rubikTextTheme(baseTheme.textTheme);
    final orbitronLarge = GoogleFonts.orbitron(
      textStyle: baseTextTheme.titleLarge ?? const TextStyle(),
    );
    final orbitronMedium = GoogleFonts.orbitron(
      textStyle: baseTextTheme.titleMedium ?? const TextStyle(),
    );

    final textTheme = baseTextTheme.copyWith(
      titleLarge: orbitronLarge.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      titleMedium: orbitronMedium.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );

    return baseTheme.copyWith(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF38BDF8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF020617),
      textTheme: textTheme,
    );
  }
}
