import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF3366D6); // Royal Blue (from mockup)
  static const Color primaryDark = Color(0xFF19409A); // Dark Royal Blue

  // Accents
  static const Color accent = Color(0xFF42A5F5); // Light Blue Accent
  static const Color accentLight = Color(
    0xFFE3EDFB,
  ); // Very Pale Blue (for New Volume card icon)

  // Backgrounds & Surfaces
  static const Color background = Color(
    0xFFEDF2F7,
  ); // Light grey-blue solid background
  static const Color backgroundAlt = Color(0xFFFFFFFF); // Pure White
  static const Color surface = Color(0xFFFFFFFF); // Pure White

  // Glass specific colors
  static final Color glassWhite = Colors.white.withValues(alpha: 0.25);
  static final Color glassBorder = Colors.white.withValues(alpha: 0.5);

  // Text
  static const Color textPrimary = Color(0xFF1F2937); // Very Dark Grey/Blue
  static const Color textSecondary = Color(0xFF6B7280); // Medium Grey

  // System
  static const Color divider = Color(0xFFE0E0E0); // Silver Line
  static const Color error = Color(0xFFE53935); // Modern Red
  static const Color success = Color(0xFF43A047); // Modern Green

  // Dark Mode specific
  static const Color darkBackground = Color(0xFF121212); // Dark
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
}

class DaVinciTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        secondary: AppColors.accent,
        onSecondary: AppColors.surface,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12),
        labelLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ), // Inter/System
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 22, // H2 equivalent
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      cardTheme: CardThemeData(
        color: AppColors.backgroundAlt,
        elevation: 2,
        shadowColor: Colors.grey.shade900.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }

  // A helper for the warm shadow used across the app
  static List<BoxShadow> get warmShadow => [
    BoxShadow(
      color: Colors.grey.shade900.withValues(alpha: 0.15),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
