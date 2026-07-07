import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors ported 1:1 from the :root CSS variables in customer.html
class AppColors {
  static const ink = Color(0xFF050807);
  static const app = Color(0xFF0B141A);
  static const chatBg = Color(0xFF0A1310);
  static const panel = Color(0xFF111F1A);
  static const panel2 = Color(0xFF16241F);
  static const line = Color(0x1A78BEAA); // rgba(120,190,170,.10)
  static const line2 = Color(0x3878BEAA); // rgba(120,190,170,.22)
  static const teal = Color(0xFF12B886);
  static const tealDeep = Color(0xFF0A5C48);
  static const gold = Color(0xFFE0B25C);
  static const goldDim = Color(0x24E0B25C); // rgba(224,178,92,.14)
  static const green = Color(0xFF3DDC97);
  static const text = Color(0xFFE8F0EC);
  static const dim = Color(0xFF8BA49B);
  static const faint = Color(0xFF5C716A);
  static const mine = Color(0xFF134D3D);
  static const other = Color(0xFF1C2B25);

  static const tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDeep],
  );
}

/// Fonts: Fraunces (display/serif), Inter Tight (body), JetBrains Mono (mono)
class AppFonts {
  static TextStyle display({
    double size = 19,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
  }) =>
      GoogleFonts.interTight(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({
    double size = 10,
    Color color = AppColors.dim,
    double letterSpacing = 0.6,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
      );
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.app,
    fontFamily: GoogleFonts.interTight().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.teal,
      secondary: AppColors.gold,
      surface: AppColors.panel,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
