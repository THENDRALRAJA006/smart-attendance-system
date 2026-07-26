// ============================================================
// SmartAttend — App Theme (v12 Premium Light)
// Material 3 light mode, Poppins font, premium university ERP
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors (Light Palette) ───────────────────────
  static const Color primary       = Color(0xFF6C63FF);
  static const Color primaryLight  = Color(0xFF8B7FFF);
  static const Color primaryDark   = Color(0xFF4A42CC);
  static const Color secondary     = Color(0xFF8B5CF6);
  static const Color accent        = Color(0xFF06B6D4); // cyan-500
  static const Color accentTeal    = Color(0xFF14B8A6); // teal-500

  static const Color success       = Color(0xFF22C55E);
  static const Color successLight  = Color(0xFFDCFCE7);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningLight  = Color(0xFFFEF3C7);
  static const Color error         = Color(0xFFEF4444);
  static const Color errorLight    = Color(0xFFFEE2E2);
  static const Color info          = Color(0xFF3B82F6);
  static const Color infoLight     = Color(0xFFDBEAFE);

  // ─── Biometric Colors (kept for BLE/Face/QR widgets) ────
  static const Color bioRing       = Color(0xFF6C63FF);
  static const Color bioAligned    = Color(0xFF22C55E);
  static const Color bioLiveness   = Color(0xFF06B6D4);
  static const Color bioQr         = Color(0xFFF59E0B);

  // ─── Background / Surface ───────────────────────────────
  static const Color bgPage        = Color(0xFFF8FAFC); // slate-50
  static const Color bgCard        = Color(0xFFFFFFFF); // pure white
  static const Color bgCardHover   = Color(0xFFF9FAFB); // gray-50
  static const Color bgMuted       = Color(0xFFF1F5F9); // slate-100
  static const Color bgOverlay     = Color(0x80000000);

  // Legacy aliases (keep for screens not yet redesigned)
  static const Color bgDark        = Color(0xFFF8FAFC);
  static const Color bgSurface     = Color(0xFFFFFFFF);
  static const Color bgCardLight   = Color(0xFFF1F5F9);

  // ─── Text Colors ────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827); // gray-900
  static const Color textSecondary = Color(0xFF6B7280); // gray-500
  static const Color textHint      = Color(0xFF9CA3AF); // gray-400
  static const Color textDisabled  = Color(0xFFD1D5DB); // gray-300
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Border / Divider ───────────────────────────────────
  static const Color border        = Color(0xFFE5E7EB); // gray-200
  static const Color borderFocus   = Color(0xFF6C63FF);

  // ─── Aliases (admin screens backward compat) ────────────
  static const Color cardBg        = bgCard;
  static const Color cardBorder    = border;

  // ─── Gradients ──────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientVert = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4A42CC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgGradientRadial = LinearGradient(
    colors: [Color(0xFFEDE9FF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Card Decorations ────────────────────────────────────
  /// Standard white card with soft shadow — use everywhere
  static BoxDecoration get glassmorphismCard => BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: border, width: 1),
    boxShadow: cardShadow,
  );

  /// Alias kept for legacy usage
  static BoxDecoration get glassCard => glassmorphismCard;

  static BoxDecoration successCard(double borderAlpha) => BoxDecoration(
    color: successLight,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: success.withValues(alpha: borderAlpha), width: 1.5),
    boxShadow: [BoxShadow(color: success.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
  );

  static BoxDecoration errorCard(double borderAlpha) => BoxDecoration(
    color: errorLight,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: error.withValues(alpha: borderAlpha), width: 1.5),
  );

  // ─── Shadows ─────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 16)),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
    BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  /// Kept for BLE/biometric screens
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.25, double blur = 24}) => [
    BoxShadow(color: color.withValues(alpha: intensity), blurRadius: blur, spreadRadius: 2),
    BoxShadow(color: color.withValues(alpha: intensity * 0.5), blurRadius: blur * 2, spreadRadius: 4),
  ];

  static List<BoxShadow> subtleGlow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
  ];

  // ─── Status Badge Decorations ────────────────────────────
  static BoxDecoration statusBadge(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
  );

  static BoxDecoration liveBadge = BoxDecoration(
    color: success.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: success.withValues(alpha: 0.3), width: 1),
  );

  // ─── Poppins Text Styles ─────────────────────────────────
  static TextStyle poppins({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
    double? height,
    double letterSpacing = 0,
  }) => GoogleFonts.poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ─── Material Light Theme ────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        outline: border,
      ),
      scaffoldBackgroundColor: bgPage,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 32),
        displayMedium: GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 28),
        displaySmall:  GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 24),
        headlineLarge: GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w700, fontSize: 24),
        headlineMedium:GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 20),
        headlineSmall: GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 18),
        titleLarge:    GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium:   GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall:    GoogleFonts.poppins(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge:     GoogleFonts.poppins(color: textSecondary, fontSize: 16, height: 1.6),
        bodyMedium:    GoogleFonts.poppins(color: textSecondary, fontSize: 14, height: 1.5),
        bodySmall:     GoogleFonts.poppins(color: textHint,      fontSize: 12, height: 1.4),
        labelLarge:    GoogleFonts.poppins(color: textPrimary,   fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:   GoogleFonts.poppins(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall:    GoogleFonts.poppins(color: textHint,      fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgCard,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0xFF000000).withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        errorStyle: GoogleFonts.poppins(color: error, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: primary, width: 1.5),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgMuted,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: bgMuted,
        circularTrackColor: bgMuted,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600, fontSize: 11);
          }
          return GoogleFonts.poppins(color: textHint, fontWeight: FontWeight.w500, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textHint, size: 22);
        }),
      ),
    );
  }

  /// Legacy alias — kept so existing code using AppTheme.darkTheme still compiles
  static ThemeData get darkTheme => lightTheme;
}
