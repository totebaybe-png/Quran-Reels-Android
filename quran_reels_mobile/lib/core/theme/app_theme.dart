import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Royal Islamic Color Palette
  static const Color bgDark = Color(0xFF0A0A12);
  static const Color bgSecondary = Color(0xFF12121E);
  static const Color bgCard = Color(0xFF171726);
  static const Color bgCardHover = Color(0xFF1E1E32);

  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF4D06F);
  static const Color goldDark = Color(0xFFAA8A2E);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C4);
  static const Color textMuted = Color(0xFF6B6B80);

  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: goldPrimary,
      colorScheme: const ColorScheme.dark(
        primary: goldPrimary,
        secondary: goldLight,
        surface: bgCard,
        error: statusError,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w600, color: goldLight),
        bodyLarge: GoogleFonts.cairo(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.cairo(fontSize: 14, color: textSecondary),
        bodySmall: GoogleFonts.cairo(fontSize: 12, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: goldLight,
        ),
        iconTheme: const IconThemeData(color: goldPrimary),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: goldPrimary.withValues(alpha: 0.15), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldPrimary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldPrimary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldPrimary, width: 2),
        ),
        hintStyle: GoogleFonts.cairo(color: textMuted, fontSize: 13),
        labelStyle: GoogleFonts.cairo(color: goldLight, fontSize: 14),
      ),
    );
  }
}
