import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_gradients.dart';

extension AppThemeExtras on ThemeData {
  LinearGradient get backgroundGradient =>
      brightness == Brightness.dark ? AppGradients.dark : AppGradients.light;
}

/// Vibrant peach gradient used for primary CTAs.
LinearGradient peachGradient(BuildContext context) {
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9E80), Color(0xFFFF8A65)],
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // ─── DARK palette (trenzy_1) ─────────────────────────────────────────────
  const darkSurface = Color(0xFF121414);
  const darkSurfaceDim = Color(0xFF121414);
  const darkSurfaceBright = Color(0xFF38393A);
  const darkSurfaceContainerLowest = Color(0xFF0C0F0F);
  const darkSurfaceContainerLow = Color(0xFF1A1C1C);
  const darkSurfaceContainer = Color(0xFF1E2020);
  const darkSurfaceContainerHigh = Color(0xFF282A2B);
  const darkSurfaceContainerHighest = Color(0xFF333535);
  const darkOnSurface = Color(0xFFE2E2E2);
  const darkOnSurfaceVariant = Color(0xFFDAC1BA);
  const darkInverseSurface = Color(0xFFE2E2E2);
  const darkInverseOnSurface = Color(0xFF2F3131);
  const darkOutline = Color(0xFFA28C86);
  const darkOutlineVariant = Color(0xFF54433E);
  const darkSurfaceTint = Color(0xFFFFB59E);
  const darkPrimary = Color(0xFFFFC6B5);
  const darkOnPrimary = Color(0xFF591C08);
  const darkPrimaryContainer = Color(0xFFFF9E80);
  const darkOnPrimaryContainer = Color(0xFF78331D);
  const darkInversePrimary = Color(0xFF944930);
  const darkSecondary = Color(0xFFC8C6C6);
  const darkOnSecondary = Color(0xFF303030);
  const darkSecondaryContainer = Color(0xFF474747);
  const darkOnSecondaryContainer = Color(0xFFB6B5B4);
  const darkTertiary = Color(0xFFD4D2D1);
  const darkOnTertiary = Color(0xFF313030);
  const darkTertiaryContainer = Color(0xFFB8B6B6);
  const darkOnTertiaryContainer = Color(0xFF484847);
  const darkError = Color(0xFFFFB4AB);
  const darkOnError = Color(0xFF690005);
  const darkErrorContainer = Color(0xFF93000A);
  const darkOnErrorContainer = Color(0xFFFFDAD6);
  const darkPrimaryFixed = Color(0xFFFFDBD0);
  const darkPrimaryFixedDim = Color(0xFFFFB59E);
  const darkOnPrimaryFixed = Color(0xFF3A0B00);
  const darkOnPrimaryFixedVariant = Color(0xFF76321C);
  const darkSecondaryFixed = Color(0xFFE4E2E1);
  const darkSecondaryFixedDim = Color(0xFFC8C6C6);
  const darkOnSecondaryFixed = Color(0xFF1B1C1C);
  const darkOnSecondaryFixedVariant = Color(0xFF474747);
  const darkTertiaryFixed = Color(0xFFE5E2E1);
  const darkTertiaryFixedDim = Color(0xFFC8C6C5);
  const darkOnTertiaryFixed = Color(0xFF1C1B1B);
  const darkOnTertiaryFixedVariant = Color(0xFF474746);
  // ─── LIGHT palette (trenzy_2) ────────────────────────────────────────────
  const lightSurface = Color(0xFFF9F9F9);
  const lightSurfaceDim = Color(0xFFDADADA);
  const lightSurfaceBright = Color(0xFFF9F9F9);
  const lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  const lightSurfaceContainerLow = Color(0xFFF3F3F3);
  const lightSurfaceContainer = Color(0xFFEEEEEE);
  const lightSurfaceContainerHigh = Color(0xFFE8E8E8);
  const lightSurfaceContainerHighest = Color(0xFFE2E2E2);
  const lightOnSurface = Color(0xFF1A1C1C);
  const lightOnSurfaceVariant = Color(0xFF54433E);
  const lightInverseSurface = Color(0xFF2F3131);
  const lightInverseOnSurface = Color(0xFFF1F1F1);
  const lightOutline = Color(0xFF87736D);
  const lightOutlineVariant = Color(0xFFDAC1BA);
  const lightSurfaceTint = Color(0xFF944930);
  const lightPrimary = Color(0xFF944930);
  const lightOnPrimary = Color(0xFFFFFFFF);
  const lightPrimaryContainer = Color(0xFFFF9E80);
  const lightOnPrimaryContainer = Color(0xFF78331D);
  const lightInversePrimary = Color(0xFFFFB59E);
  const lightSecondary = Color(0xFF5F5E5E);
  const lightOnSecondary = Color(0xFFFFFFFF);
  const lightSecondaryContainer = Color(0xFFE4E2E1);
  const lightOnSecondaryContainer = Color(0xFF656464);
  const lightTertiary = Color(0xFF5F5E5E);
  const lightOnTertiary = Color(0xFFFFFFFF);
  const lightTertiaryContainer = Color(0xFFB8B6B6);
  const lightOnTertiaryContainer = Color(0xFF484847);
  const lightError = Color(0xFFBA1A1A);
  const lightOnError = Color(0xFFFFFFFF);
  const lightErrorContainer = Color(0xFFFFDAD6);
  const lightOnErrorContainer = Color(0xFF93000A);
  const lightPrimaryFixed = Color(0xFFFFDBD0);
  const lightPrimaryFixedDim = Color(0xFFFFB59E);
  const lightOnPrimaryFixed = Color(0xFF3A0B00);
  const lightOnPrimaryFixedVariant = Color(0xFF76321C);
  const lightSecondaryFixed = Color(0xFFE4E2E1);
  const lightSecondaryFixedDim = Color(0xFFC8C6C6);
  const lightOnSecondaryFixed = Color(0xFF1B1C1C);
  const lightOnSecondaryFixedVariant = Color(0xFF474747);
  const lightTertiaryFixed = Color(0xFFE5E2E1);
  const lightTertiaryFixedDim = Color(0xFFC8C6C5);
  const lightOnTertiaryFixed = Color(0xFF1C1B1B);
  const lightOnTertiaryFixedVariant = Color(0xFF474746);
  // Select palette
  final surface = isDark ? darkSurface : lightSurface;
  final surfaceDim = isDark ? darkSurfaceDim : lightSurfaceDim;
  final surfaceBright = isDark ? darkSurfaceBright : lightSurfaceBright;
  final surfaceContainerLowest = isDark
      ? darkSurfaceContainerLowest
      : lightSurfaceContainerLowest;
  final surfaceContainerLow = isDark
      ? darkSurfaceContainerLow
      : lightSurfaceContainerLow;
  final surfaceContainer = isDark
      ? darkSurfaceContainer
      : lightSurfaceContainer;
  final surfaceContainerHigh = isDark
      ? darkSurfaceContainerHigh
      : lightSurfaceContainerHigh;
  final surfaceContainerHighest = isDark
      ? darkSurfaceContainerHighest
      : lightSurfaceContainerHighest;
  final onSurface = isDark ? darkOnSurface : lightOnSurface;
  final onSurfaceVariant = isDark
      ? darkOnSurfaceVariant
      : lightOnSurfaceVariant;
  final inverseSurface = isDark ? darkInverseSurface : lightInverseSurface;
  final inverseOnSurface = isDark
      ? darkInverseOnSurface
      : lightInverseOnSurface;
  final outline = isDark ? darkOutline : lightOutline;
  final outlineVariant = isDark ? darkOutlineVariant : lightOutlineVariant;
  final primary = isDark ? darkPrimary : lightPrimary;
  final onPrimary = isDark ? darkOnPrimary : lightOnPrimary;
  final primaryContainer = isDark
      ? darkPrimaryContainer
      : lightPrimaryContainer;
  final onPrimaryContainer = isDark
      ? darkOnPrimaryContainer
      : lightOnPrimaryContainer;
  final inversePrimary = isDark ? darkInversePrimary : lightInversePrimary;
  final secondary = isDark ? darkSecondary : lightSecondary;
  final onSecondary = isDark ? darkOnSecondary : lightOnSecondary;
  final secondaryContainer = isDark
      ? darkSecondaryContainer
      : lightSecondaryContainer;
  final onSecondaryContainer = isDark
      ? darkOnSecondaryContainer
      : lightOnSecondaryContainer;
  final tertiary = isDark ? darkTertiary : lightTertiary;
  final onTertiary = isDark ? darkOnTertiary : lightOnTertiary;
  final tertiaryContainer = isDark
      ? darkTertiaryContainer
      : lightTertiaryContainer;
  final onTertiaryContainer = isDark
      ? darkOnTertiaryContainer
      : lightOnTertiaryContainer;
  final error = isDark ? darkError : lightError;
  final onError = isDark ? darkOnError : lightOnError;
  final errorContainer = isDark ? darkErrorContainer : lightErrorContainer;
  final onErrorContainer = isDark
      ? darkOnErrorContainer
      : lightOnErrorContainer;
  final surfaceTint = isDark ? darkSurfaceTint : lightSurfaceTint;
  final primaryFixed = isDark ? darkPrimaryFixed : lightPrimaryFixed;
  final primaryFixedDim = isDark ? darkPrimaryFixedDim : lightPrimaryFixedDim;
  final onPrimaryFixed = isDark ? darkOnPrimaryFixed : lightOnPrimaryFixed;
  final onPrimaryFixedVariant = isDark
      ? darkOnPrimaryFixedVariant
      : lightOnPrimaryFixedVariant;
  final secondaryFixed = isDark ? darkSecondaryFixed : lightSecondaryFixed;
  final secondaryFixedDim = isDark
      ? darkSecondaryFixedDim
      : lightSecondaryFixedDim;
  final onSecondaryFixed = isDark
      ? darkOnSecondaryFixed
      : lightOnSecondaryFixed;
  final onSecondaryFixedVariant = isDark
      ? darkOnSecondaryFixedVariant
      : lightOnSecondaryFixedVariant;
  final tertiaryFixed = isDark ? darkTertiaryFixed : lightTertiaryFixed;
  final tertiaryFixedDim = isDark
      ? darkTertiaryFixedDim
      : lightTertiaryFixedDim;
  final onTertiaryFixed = isDark ? darkOnTertiaryFixed : lightOnTertiaryFixed;
  final onTertiaryFixedVariant = isDark
      ? darkOnTertiaryFixedVariant
      : lightOnTertiaryFixedVariant;
  // Typography
  final plusJakarta = GoogleFonts.plusJakartaSans();
  final textTheme =
      GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          height: 48 / 40,
          letterSpacing: -0.02,
          color: onSurface,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          height: 44 / 36,
          letterSpacing: -0.02,
          color: onSurface,
        ),
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 40 / 32,
          letterSpacing: -0.01,
          color: onSurface,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 40 / 32,
          letterSpacing: -0.01,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 36 / 28,
          color: onSurface,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 32 / 24,
          color: onSurface,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 28 / 20,
          color: onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 24 / 16,
          color: onSurface,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
          color: onSurface,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 16 / 12,
          color: onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          color: onSurface,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
          color: onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 16 / 11,
          color: onSurfaceVariant,
        ),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: surface,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      inversePrimary: inversePrimary,
      surfaceTint: surfaceTint,
      primaryFixed: primaryFixed,
      primaryFixedDim: primaryFixedDim,
      onPrimaryFixed: onPrimaryFixed,
      onPrimaryFixedVariant: onPrimaryFixedVariant,
      secondaryFixed: secondaryFixed,
      secondaryFixedDim: secondaryFixedDim,
      onSecondaryFixed: onSecondaryFixed,
      onSecondaryFixedVariant: onSecondaryFixedVariant,
      tertiaryFixed: tertiaryFixed,
      tertiaryFixedDim: tertiaryFixedDim,
      onTertiaryFixed: onTertiaryFixed,
      onTertiaryFixedVariant: onTertiaryFixedVariant,
    ),
    textTheme: textTheme,
    fontFamily: plusJakarta.fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.15,
        color: primary,
      ),
    ),
    cardColor: surfaceContainerLow,
    dividerColor: outlineVariant.withValues(alpha: 0.3),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? surfaceContainerHigh : surfaceContainer,
      selectedColor: primaryContainer,
      disabledColor: onSurface.withValues(alpha: 0.08),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
      secondaryLabelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF0C0F0F) : const Color(0xFFFFFFFF),
      ),
      side: BorderSide(color: outlineVariant.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface.withValues(alpha: 0.45),
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryContainer,
        foregroundColor: isDark
            ? const Color(0xFF0C0F0F)
            : const Color(0xFF2D2D2D),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        minimumSize: const Size(0, 52),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryContainer,
        foregroundColor: isDark
            ? const Color(0xFF0C0F0F)
            : const Color(0xFF2D2D2D),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: onSurface,
      tileColor: surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: IconThemeData(color: onSurface),
    cardTheme: CardThemeData(
      color: surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineVariant.withValues(alpha: 0.25)),
      ),
    ),
    shadowColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: surfaceContainer,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF1E2020)
          : const Color(0xFF1A1C1C),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      actionTextColor: primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: 0.85),
      indicatorColor: primary.withValues(alpha: 0.15),
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primary : onSurfaceVariant,
          size: 24,
        );
      }),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: 0.85),
      selectedItemColor: primary,
      unselectedItemColor: onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
