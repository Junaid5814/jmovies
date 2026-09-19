import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jmovies "Premium Dark Cinema" palette.
class AppColors {
  AppColors._();

  static const Color pureBlack = Color(0xFF000000);
  static const Color charcoal = Color(0xFF121212);
  static const Color charcoalElevated = Color(0xFF1C1C1E);
  static const Color surfaceCard = Color(0xFF201F22);

  static const Color crimson = Color(0xFFE50914);
  static const Color crimsonDark = Color(0xFF9B0710);
  static const Color crimsonGlow = Color(0x33E50914); // 20% alpha for glows

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1A6);
  static const Color textMuted = Color(0xFF6E6E73);

  static const Color gold = Color(0xFFFFC94A); // rating star accent
  static const Color success = Color(0xFF34C759);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkCinema {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textMuted,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.pureBlack,
      canvasColor: AppColors.pureBlack,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.crimson,
        secondary: AppColors.crimson,
        surface: AppColors.charcoal,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.charcoal,
        selectedItemColor: AppColors.crimson,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.charcoalElevated,
        selectedColor: AppColors.crimson,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.crimson,
        inactiveTrackColor: Colors.white24,
        thumbColor: AppColors.crimson,
        overlayColor: AppColors.crimsonGlow,
        trackHeight: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.crimson,
      ),
    );
  }
}
