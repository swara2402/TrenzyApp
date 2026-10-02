import 'dart:ui';
import 'package:flutter/material.dart';

export '../widgets/glass_widgets.dart';
export '../widgets/app_widgets.dart';
export 'app_spacing.dart';
export 'trenzy_colors.dart';

class GlassColors {
  GlassColors._();

  static const Color background = Color(0xFF120F0E);
  static const Color foreground = Color(0xFFFAF6F0);

  static const Color primary = Color(0xFFD79D8A);
  static const Color primaryFg = Color(0xFF120F0E);
  static const Color primaryDim = Color(0xFFB87F6F);

  static const Color emerald = Color(0xFF7CB7A5);
  static const Color crimson = Color(0xFFE07A70);

  static const Color glass = Color(0x14FAF6F0);
  static const Color glassBorder = Color(0x1AFAF6F0);
  static const Color glassDockBorder = Color(0x1FFAF6F0);
  static const Color glassDock = Color(0xC0191514);

  static const Color mutedFg = Color(0xFFA89F95);

  static const Color graphite = Color(0xFF251F1D);
  static const Color black = Color(0xFF000000);
  static const Color white15 = Color(0x26FAF6F0);
  static const Color white08 = Color(0x14FAF6F0);
  static const Color white10 = Color(0x1AFAF6F0);
  static const Color white20 = Color(0x33FAF6F0);
  static const Color white30 = Color(0x4DFAF6F0);
  static const Color white40 = Color(0x66FAF6F0);
  static const Color white50 = Color(0x80FAF6F0);
  static const Color white60 = Color(0x99FAF6F0);
  static const Color white70 = Color(0xB3FAF6F0);
  static const Color white80 = Color(0xCCFAF6F0);
  static const Color white90 = Color(0xE6FAF6F0);

  static const Color fg08 = white08;
  static const Color fg10 = white10;
  static const Color fg15 = white15;
  static const Color fg20 = white20;
  static const Color fg30 = white30;
  static const Color fg40 = white40;
  static const Color fg50 = white50;
  static const Color fg60 = white60;
  static const Color fg70 = white70;
  static const Color fg80 = white80;
  static const Color fg90 = white90;

  static const Color destructive = Color(0xFFE07A70);
}

class GlassGradients {
  GlassGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE2A997), Color(0xFFC78977)],
  );

  static const LinearGradient match = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFD79D8A), Color(0xFF7CB7A5)],
  );

  static const LinearGradient imageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xD9000000),
      Color(0x1A000000),
      Color(0x66000000),
    ],
  );

  static const LinearGradient glassSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x14FAF6F0),
      Color(0x06FAF6F0),
    ],
  );

  static const RadialGradient auraGold = RadialGradient(
    center: Alignment(0.3, 0.2),
    radius: 0.7,
    colors: [Color(0x1CD79D8A), Colors.transparent],
    stops: [0.0, 0.7],
  );

  static const RadialGradient auraGreen = RadialGradient(
    center: Alignment(0.8, 0.2),
    radius: 0.65,
    colors: [Color(0x1C7CB7A5), Colors.transparent],
    stops: [0.0, 0.7],
  );
}

class GlassTypography {
  GlassTypography._();

  static const String bodyFont = 'PlusJakartaSans';

  static TextStyle display({
    double fontSize = 24,
    Color? color,
    FontWeight weight = FontWeight.w800,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? -0.02 * (fontSize / 24),
      height: 1.1,
    );
  }

  static TextStyle meta({
    Color? color,
    double fontSize = 10,
  }) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color ?? GlassColors.fg40,
      letterSpacing: 1.4,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height ?? 1.4,
    );
  }

  static TextStyle buttonLabel({
    Color? color,
    double fontSize = 15,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? GlassColors.primaryFg,
      letterSpacing: 0.3,
    );
  }

  static TextStyle caption({
    Color? color,
  }) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color ?? GlassColors.fg80,
      height: 1.3,
    );
  }
}

BoxDecoration glassDecoration({
  double radius = 28,
  Color? color,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color ?? GlassColors.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? GlassColors.glassBorder,
      width: 1,
    ),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x14FAF6F0), Color(0x06FAF6F0)],
    ),
  );
}

BoxDecoration glassDockDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: GlassColors.glassDock,
    borderRadius: BorderRadius.circular(32),
    border: Border.all(
      color: borderColor ?? GlassColors.glassDockBorder,
      width: 1,
    ),
  );
}

BoxDecoration glowBorder({double radius = 20}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: GlassColors.primary.withValues(alpha: 0.15),
      width: 1.5,
    ),
  );
}

BoxDecoration auraDecoration(String aura) {
  switch (aura) {
    case 'green':
      return const BoxDecoration(gradient: GlassGradients.auraGreen);
    default:
      return const BoxDecoration(gradient: GlassGradients.auraGold);
  }
}

class GlassSpacing {
  GlassSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class GlassRadius {
  GlassRadius._();
  static const double card = 20;
  static const double panel = 20;
  static const double button = 16;
  static const double chip = 16;
  static const double input = 16;
  static const double searchBar = 18;
  static const double dialog = 24;
  static const double sheet = 28;
  static const double dock = 32;
  static const double pill = 999;
}

class GlassAnimations {
  GlassAnimations._();

  static const Duration press = Duration(milliseconds: 120);
  static const Duration toggle = Duration(milliseconds: 200);
  static const Duration tabSwitch = Duration(milliseconds: 250);
  static const Duration viewTransition = Duration(milliseconds: 320);

  static const Duration everyday = Duration(milliseconds: 250);
  static const Duration feature = Duration(milliseconds: 500);
  static const Duration signature = Duration(milliseconds: 1000);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;

  static const double springStiffness = 320;
  static const double springDamping = 34;
}

class GlassShadows {
  GlassShadows._();

  static BoxShadow card = BoxShadow(
    color: Colors.black.withValues(alpha: 0.25),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static BoxShadow cardPressed = BoxShadow(
    color: Colors.black.withValues(alpha: 0.35),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static BoxShadow glow = BoxShadow(
    color: GlassColors.primary.withValues(alpha: 0.15),
    blurRadius: 24,
    spreadRadius: -4,
  );

  static BoxShadow glowIntense = BoxShadow(
    color: GlassColors.primary.withValues(alpha: 0.35),
    blurRadius: 32,
    spreadRadius: -2,
  );

  static BoxShadow dockGlow = BoxShadow(
    color: GlassColors.primary.withValues(alpha: 0.08),
    blurRadius: 20,
    spreadRadius: -5,
  );

  static BoxShadow navActive = BoxShadow(
    color: GlassColors.primary.withValues(alpha: 0.25),
    blurRadius: 16,
    spreadRadius: -2,
  );

  /// Soft outer glow for elevated elements
  static BoxShadow softOuterGlow = BoxShadow(
    color: GlassColors.primary.withValues(alpha: 0.06),
    blurRadius: 40,
    spreadRadius: -8,
  );

  static BoxShadow emeraldGlow = BoxShadow(
    color: GlassColors.emerald.withValues(alpha: 0.15),
    blurRadius: 20,
    spreadRadius: -4,
  );
}

String fmt(int n) {
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}k';
  }
  return n.toString();
}

ImageFilter glassBlur({double sigma = 25}) {
  return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
}