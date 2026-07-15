import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tracks the device's current system light/dark setting. [AiDoubleApp]
/// observes OS theme changes and rebuilds the tree on change, so every
/// AppColors getter below (which reads this fresh on each call) switches
/// live while the app is open — no restart needed.
bool get _isDark => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

/// The app's color palette, named by role (not by hue), with a light and
/// dark value for everything except the brand accent
/// ([appPrimaryColor]/[appOnPrimaryColor], which stay fixed across both
/// themes). Values are getters (not const) so they can react to
/// [_isDark] — re-theming the app (e.g. teal → blue) only means editing
/// [appPrimaryColor] and the light/dark pairs below.
class AppColors {
  static const appInkColor = Color(0xFF050807);

  static Color get appBackgroundColor => _isDark ? const Color(0xFF0B141A) : const Color(0xFFF4F8F6);
  static Color get appChatBackgroundColor => _isDark ? const Color(0xFF0A1310) : const Color(0xFFEFF5F1);
  static Color get appSurfaceColor => _isDark ? const Color(0xFF111F1A) : const Color(0xFFFFFFFF);
  static Color get appSurfaceVariantColor => _isDark ? const Color(0xFF16241F) : const Color(0xFFEFF3F1);

  /// The one color to change to re-theme the app (e.g. teal → blue) — kept
  /// the same across light/dark for brand consistency.
  static const appPrimaryColor = Color(0xFF12B886);

  // Derived from appPrimaryColor by percentage, recomputed on each access
  // since appBackgroundColor now depends on the current system theme.
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
  static Color get appTextColor => _isDark ? const Color(0xFFE8F0EC) : const Color(0xFF0E1712);
  static Color get appTextSecondaryColor => _isDark ? const Color(0xFF8BA49B) : const Color(0xFF54685F);
  static Color get appTextMutedColor => _isDark ? const Color(0xFF5C716A) : const Color(0xFF93A69D);
  static Color get appChatBubbleOtherColor => _isDark ? const Color(0xFF1C2B25) : const Color(0xFFE3EAE6);

  // Text/icon color for content sitting on top of the primary accent
  // (FABs, send buttons, primary CTAs) — the accent itself doesn't change
  // between themes, so this stays fixed too.
  static const appOnPrimaryColor = Color(0xFF04120D);
}

/// Fonts: Fraunces (display/serif), Inter Tight (body), JetBrains Mono (mono)
class AppFonts {
  // `color` can't default to AppColors.appTextColor anymore (getters
  // aren't compile-time constants) — default to null and resolve inside.
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
