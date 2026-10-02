import 'package:flutter/material.dart';

class TrenzyColors extends ThemeExtension<TrenzyColors> {
  final Color background;
  final Color foreground;
  final Color primary;
  final Color primaryFg;
  final Color primaryDim;
  final Color emerald;
  final Color crimson;
  final Color glass;
  final Color glassBorder;
  final Color glassDockBorder;
  final Color glassDock;
  final Color mutedFg;
  final Color graphite;
  final Color surfaceContainer;
  final Color destructive;

  final Color fg08;
  final Color fg10;
  final Color fg15;
  final Color fg20;
  final Color fg30;
  final Color fg40;
  final Color fg50;
  final Color fg60;
  final Color fg70;
  final Color fg80;
  final Color fg90;

  const TrenzyColors({
    required this.background,
    required this.foreground,
    required this.primary,
    required this.primaryFg,
    required this.primaryDim,
    required this.emerald,
    required this.crimson,
    required this.glass,
    required this.glassBorder,
    required this.glassDockBorder,
    required this.glassDock,
    required this.mutedFg,
    required this.graphite,
    required this.surfaceContainer,
    required this.destructive,
    required this.fg08,
    required this.fg10,
    required this.fg15,
    required this.fg20,
    required this.fg30,
    required this.fg40,
    required this.fg50,
    required this.fg60,
    required this.fg70,
    required this.fg80,
    required this.fg90,
  });

  static const dark = TrenzyColors(
    background: Color(0xFF120F0E),
    foreground: Color(0xFFFAF6F0),
    primary: Color(0xFFD79D8A),
    primaryFg: Color(0xFF120F0E),
    primaryDim: Color(0xFFB87F6F),
    emerald: Color(0xFF7CB7A5),
    crimson: Color(0xFFE07A70),
    glass: Color(0x14FAF6F0),
    glassBorder: Color(0x1AFAF6F0),
    glassDockBorder: Color(0x1FFAF6F0),
    glassDock: Color(0xC0191514),
    mutedFg: Color(0xFFA89F95),
    graphite: Color(0xFF251F1D),
    surfaceContainer: Color(0xFF1C1715),
    destructive: Color(0xFFE07A70),
    fg08: Color(0x14FAF6F0),
    fg10: Color(0x1AFAF6F0),
    fg15: Color(0x26FAF6F0),
    fg20: Color(0x33FAF6F0),
    fg30: Color(0x4DFAF6F0),
    fg40: Color(0x66FAF6F0),
    fg50: Color(0x80FAF6F0),
    fg60: Color(0x99FAF6F0),
    fg70: Color(0xB3FAF6F0),
    fg80: Color(0xCCFAF6F0),
    fg90: Color(0xE6FAF6F0),
  );

  static const light = TrenzyColors(
    background: Color(0xFFFBF8F5),
    foreground: Color(0xFF1F1A19),
    primary: Color(0xFFC98C7D),
    primaryFg: Color(0xFFFAF6F0),
    primaryDim: Color(0xFFB57565),
    emerald: Color(0xFF7EA899),
    crimson: Color(0xFFE0746A),
    glass: Color(0x0F1F1A19),
    glassBorder: Color(0x1A1F1A19),
    glassDockBorder: Color(0x241F1A19),
    glassDock: Color(0xF4F6F2EF),
    mutedFg: Color(0xFF7A6E68),
    graphite: Color(0xFFEFE8E3),
    surfaceContainer: Color(0xFFF5EFEA),
    destructive: Color(0xFFE0746A),
    fg08: Color(0x141F1A19),
    fg10: Color(0x1A1F1A19),
    fg15: Color(0x261F1A19),
    fg20: Color(0x331F1A19),
    fg30: Color(0x4D1F1A19),
    fg40: Color(0x731F1A19),
    fg50: Color(0x8C1F1A19),
    fg60: Color(0xA61F1A19),
    fg70: Color(0xBF1F1A19),
    fg80: Color(0xCC1F1A19),
    fg90: Color(0xE61F1A19),
  );

  @override
  TrenzyColors copyWith({
    Color? background,
    Color? foreground,
    Color? primary,
    Color? primaryFg,
    Color? primaryDim,
    Color? emerald,
    Color? crimson,
    Color? glass,
    Color? glassBorder,
    Color? glassDockBorder,
    Color? glassDock,
    Color? mutedFg,
    Color? graphite,
    Color? surfaceContainer,
    Color? destructive,
    Color? fg08,
    Color? fg10,
    Color? fg15,
    Color? fg20,
    Color? fg30,
    Color? fg40,
    Color? fg50,
    Color? fg60,
    Color? fg70,
    Color? fg80,
    Color? fg90,
  }) {
    return TrenzyColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      primary: primary ?? this.primary,
      primaryFg: primaryFg ?? this.primaryFg,
      primaryDim: primaryDim ?? this.primaryDim,
      emerald: emerald ?? this.emerald,
      crimson: crimson ?? this.crimson,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      glassDockBorder: glassDockBorder ?? this.glassDockBorder,
      glassDock: glassDock ?? this.glassDock,
      mutedFg: mutedFg ?? this.mutedFg,
      graphite: graphite ?? this.graphite,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      destructive: destructive ?? this.destructive,
      fg08: fg08 ?? this.fg08,
      fg10: fg10 ?? this.fg10,
      fg15: fg15 ?? this.fg15,
      fg20: fg20 ?? this.fg20,
      fg30: fg30 ?? this.fg30,
      fg40: fg40 ?? this.fg40,
      fg50: fg50 ?? this.fg50,
      fg60: fg60 ?? this.fg60,
      fg70: fg70 ?? this.fg70,
      fg80: fg80 ?? this.fg80,
      fg90: fg90 ?? this.fg90,
    );
  }

  @override
  TrenzyColors lerp(ThemeExtension<TrenzyColors>? other, double t) {
    if (other is! TrenzyColors) return this;
    return TrenzyColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryFg: Color.lerp(primaryFg, other.primaryFg, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      crimson: Color.lerp(crimson, other.crimson, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassDockBorder: Color.lerp(glassDockBorder, other.glassDockBorder, t)!,
      glassDock: Color.lerp(glassDock, other.glassDock, t)!,
      mutedFg: Color.lerp(mutedFg, other.mutedFg, t)!,
      graphite: Color.lerp(graphite, other.graphite, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      fg08: Color.lerp(fg08, other.fg08, t)!,
      fg10: Color.lerp(fg10, other.fg10, t)!,
      fg15: Color.lerp(fg15, other.fg15, t)!,
      fg20: Color.lerp(fg20, other.fg20, t)!,
      fg30: Color.lerp(fg30, other.fg30, t)!,
      fg40: Color.lerp(fg40, other.fg40, t)!,
      fg50: Color.lerp(fg50, other.fg50, t)!,
      fg60: Color.lerp(fg60, other.fg60, t)!,
      fg70: Color.lerp(fg70, other.fg70, t)!,
      fg80: Color.lerp(fg80, other.fg80, t)!,
      fg90: Color.lerp(fg90, other.fg90, t)!,
    );
  }

  static TrenzyColors of(BuildContext context) {
    return Theme.of(context).extension<TrenzyColors>() ?? dark;
  }
}

extension TrenzyColorsX on BuildContext {
  TrenzyColors get trenzyColors => TrenzyColors.of(this);
}
