import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


bool get _isDark => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

class AppColors {
  static const appInkColor = Color(0xFF050807);

  static Color get appBackgroundColor => _isDark ? const Color(0xFF0B141A) : const Color(0xFFF4F8F6);
  static Color get appChatBackgroundColor => _isDark ? const Color(0xFF0A1310) : const Color(0xFFEFF5F1);
  static Color get appSurfaceColor => _isDark ? const Color(0xFF111F1A) : const Color(0xFFFFFFFF);
  static Color get appSurfaceVariantColor => _isDark ? const Color(0xFF16241F) : const Color(0xFFEFF3F1);

  static const appPrimaryColor = Color(0xFF12B886);

  static Color get appPrimaryDarkColor => Color.lerp(appPrimaryColor, Colors.black, 0.35)!;
  static Color get appBorderColor => appPrimaryColor.withOpacity(0.10);
  static Color get appBorderColorStrong => appPrimaryColor.withOpacity(0.22);
  static Color get appChatBubbleMineColor => Color.lerp(appPrimaryColor, appBackgroundColor, 0.78)!;
  static LinearGradient get appPrimaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [appPrimaryColor, appPrimaryDarkColor],
      );

  static Color get appSecondaryColor => _isDark ? const Color(0xFFE0B25C) : const Color(0xFFB07A2A);
  static Color get appSecondaryColorDim => _isDark ? const Color(0x24E0B25C) : const Color(0x24B07A2A);
  static Color get appSuccessColor => _isDark ? const Color(0xFF3DDC97) : const Color(0xFF1E9E63);
static Color get appTextColor =>
    _isDark
        ? const Color(0xFFC9CFCC)
        : const Color(0xFF0E1712);  static Color get appTextSecondaryColor => _isDark ? const Color(0xFF8BA49B) : const Color(0xFF54685F);
  static Color get appTextMutedColor => _isDark ? const Color(0xFF5C716A) : const Color(0xFF93A69D);
  static Color get appChatBubbleOtherColor => _isDark ? const Color(0xFF1C2B25) : const Color(0xFFE3EAE6);

  static const appOnPrimaryColor = Color(0xFF04120D);
}

class AppFonts {
  
  static TextStyle display({
    double size = 19,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.appTextColor,
        letterSpacing: -0.2,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.interTight(fontSize: size, fontWeight: weight, color: color ?? AppColors.appTextColor);

  static TextStyle mono({
    double size = 10,
    Color? color,
    double letterSpacing = 0.6,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color ?? AppColors.appTextSecondaryColor,
        letterSpacing: letterSpacing,
      );
}

ThemeData buildAppTheme() {
  final dark = _isDark;
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.appBackgroundColor,
    fontFamily: GoogleFonts.interTight().fontFamily,
    colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: AppColors.appPrimaryColor,
      secondary: AppColors.appSecondaryColor,
      surface: AppColors.appSurfaceColor,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Toast/snackbar look, defined once here so every ScaffoldMessenger
    // .showSnackBar(...) call in the app gets a readable, on-brand toast
    // without needing to repeat colors at each call site.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.appSurfaceVariantColor,
      contentTextStyle: AppFonts.body(size: 13.5, color: AppColors.appTextColor),
      actionTextColor: AppColors.appPrimaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.appBorderColor),
      ),
    ),
  );
}
