// ============================================================
// SmartAttend — App Theme
// Primary: #7C5CFF | Dark glassmorphism
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors ───────────────────────────────────────
  static const Color primary = Color(0xFF7C5CFF);
  static const Color primaryLight = Color(0xFF9B7FFF);
  static const Color primaryDark = Color(0xFF5A3FCC);
  static const Color accent = Color(0xFF00D4FF);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);

  // ─── Background Colors ──────────────────────────────────
  static const Color bgDark = Color(0xFF0A0A1A);
  static const Color bgSurface = Color(0xFF12122A);
  static const Color bgCard = Color(0xFF1A1A35);
  static const Color bgCardLight = Color(0xFF1E1E40);

  // ─── Text Colors ────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0FF);
  static const Color textSecondary = Color(0xFFB0B0CC);
  static const Color textHint = Color(0xFF6060A0);

  // ─── Gradients ──────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF9B7FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0A0A1A), Color(0xFF12122A), Color(0xFF1A1235)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDD2C00), Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Glass Decoration ───────────────────────────────────
  static BoxDecoration get glassmorphismCard => BoxDecoration(
        color: bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      );

  static BoxDecoration get glassCard => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ─── Material Theme ─────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bgDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineLarge: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.15),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
