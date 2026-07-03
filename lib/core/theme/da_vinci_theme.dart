import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF6F4E37); // Dark Sepia Brown
  static const Color primaryDark = Color(0xFF4A3222); // Deep Umber
  
  // Accents
  static const Color accent = Color(0xFFC9A227); // Antique Gold
  static const Color accentLight = Color(0xFFE8C766); // Pale Gold
  
  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF4ECD8); // Parchment/Ivory
  static const Color backgroundAlt = Color(0xFFEFE6D0); // Aged Parchment
  static const Color surface = Color(0xFFFBF7ED); // Warm White
  
  // Text
  static const Color textPrimary = Color(0xFF2B2015); // Ink Black-Brown
  static const Color textSecondary = Color(0xFF6B5D4F); // Faded Ink
  
  // System
  static const Color divider = Color(0x66C9A227); // Brass Line (~40% opacity of Gold)
  static const Color error = Color(0xFFA13D2E); // Wax Red
  static const Color success = Color(0xFF5C7A5A); // Verdigris Green
  
  // Dark Mode specific
  static const Color darkBackground = Color(0xFF1C1712); // Ink-well black-brown
  static const Color darkSurface = Color(0xFF28211A);
  static const Color darkTextSecondary = Color(0xFFA69880);
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
        displayLarge: GoogleFonts.cinzel(color: AppColors.textPrimary),
        headlineLarge: GoogleFonts.cormorantGaramond(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.cormorantGaramond(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        headlineSmall: GoogleFonts.cormorantGaramond(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.crimsonText(color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.crimsonText(color: AppColors.textPrimary),
        bodySmall: GoogleFonts.crimsonText(color: AppColors.textPrimary),
        labelLarge: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, color: AppColors.textPrimary), // Inter/System
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: 22, // H2 equivalent
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      cardTheme: CardThemeData(
        color: AppColors.backgroundAlt,
        elevation: 2,
        shadowColor: Colors.brown.shade900.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
      color: Colors.brown.shade900.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 2),
    )
  ];
}
