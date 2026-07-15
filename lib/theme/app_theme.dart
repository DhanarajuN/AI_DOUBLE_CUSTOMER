import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppColors {
  static const appInkColor = Color(0xFF050807);
  static const appBackgroundColor = Color(0xFF0B141A);
  static const appChatBackgroundColor = Color(0xFF0A1310);
  static const appSurfaceColor = Color(0xFF111F1A);
  static const appSurfaceVariantColor = Color(0xFF16241F);

  static const appPrimaryColor = Color(0xFF12B886);

 
  static final appPrimaryDarkColor = Color.lerp(appPrimaryColor, Colors.black, 0.35)!;
  static final appBorderColor = appPrimaryColor.withOpacity(0.10);
  static final appBorderColorStrong = appPrimaryColor.withOpacity(0.22);
  static final appChatBubbleMineColor = Color.lerp(appPrimaryColor, appBackgroundColor, 0.78)!;
  static final appPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [appPrimaryColor, appPrimaryDarkColor],
  );

  static const appSecondaryColor = Color(0xFFE0B25C);
  static const appSecondaryColorDim = Color(0x24E0B25C);
  static const appSuccessColor = Color(0xFF3DDC97);
  static const appTextColor = Color(0xFFE8F0EC);
  static const appTextSecondaryColor = Color(0xFF8BA49B);
  static const appTextMutedColor = Color(0xFF5C716A);
  static const appChatBubbleOtherColor = Color(0xFF1C2B25);


  static const appOnPrimaryColor = Color(0xFF04120D);
}

class AppFonts {
  static TextStyle display({
    double size = 19,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.appTextColor,
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
    Color color = AppColors.appTextColor,
  }) =>
      GoogleFonts.interTight(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({
    double size = 10,
    Color color = AppColors.appTextSecondaryColor,
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
    scaffoldBackgroundColor: AppColors.appBackgroundColor,
    fontFamily: GoogleFonts.interTight().fontFamily,
    colorScheme: const ColorScheme.dark(
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
