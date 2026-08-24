import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Luz de barrio: papel crema, acento amarillo, tinta cálida. Sin modo oscuro.
class NeeColors {
  static const vest = Color(0xFFFFD000);
  static const yellow = vest;
  static const yellowDeep = Color(0xFFE6B800);
  static const soot = Color(0xFF3A3328);
  static const ink = soot;
  static const paper = Color(0xFFFFF6E4);
  static const cream = paper;
  static const chalk = Color(0xFFFFFDF8);
  static const surface = chalk;
  static const muted = Color(0xFF7A7264);
  static const open = Color(0xFF1F6B45);
  static const success = open;
  static const waiting = Color(0xFFD35400);
  static const assigned = Color(0xFF1F4E8C);
}

class NeeRadii {
  static const tile = 20.0;
  static const dial = 28.0;
  static const pill = 999.0;
}

class NeeTheme {
  static TextTheme _texts(TextTheme base, Color ink, Color muted) {
    return base.copyWith(
      displayLarge: GoogleFonts.archivoBlack(
        fontSize: 36,
        height: 1.02,
        color: ink,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        height: 1.1,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        height: 1.4,
        color: ink,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 15,
        height: 1.4,
        color: ink,
      ),
      labelSmall: GoogleFonts.ibmPlexMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: muted,
      ),
    );
  }

  static ThemeData light() => _build(
        brightness: Brightness.light,
        ink: NeeColors.soot,
        paper: NeeColors.paper,
        face: NeeColors.chalk,
        muted: NeeColors.muted,
      );

  static const thinIcons = IconThemeData(
    size: 22,
    fill: 0,
    weight: 200,
    grade: -25,
    opticalSize: 24,
    color: NeeColors.soot,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color ink,
    required Color paper,
    required Color face,
    required Color muted,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );
    final texts = _texts(base.textTheme, ink, muted);
    final scheme = ColorScheme.fromSeed(
      seedColor: NeeColors.vest,
      brightness: brightness,
      primary: NeeColors.vest,
      onPrimary: NeeColors.soot,
      surface: face,
      onSurface: ink,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: texts,
      iconTheme: thinIcons.copyWith(color: ink),
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NeeColors.vest,
          foregroundColor: NeeColors.soot,
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeeRadii.tile),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: ink.withValues(alpha: 0.22)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NeeRadii.tile),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: face,
        hintStyle: GoogleFonts.outfit(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeeRadii.dial),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeeRadii.dial),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NeeRadii.dial),
          borderSide: const BorderSide(color: NeeColors.vest, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: face,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeeRadii.tile),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: face,
        indicatorColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return thinIcons.copyWith(
            color: selected ? NeeColors.soot : muted,
            weight: selected ? 300 : 200,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? ink : muted,
          );
        }),
      ),
    );
  }
}
