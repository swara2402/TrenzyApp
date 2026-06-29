import 'package:flutter/material.dart';

/// Trenzy v1.0 Design System — Production Frozen Specification
///
/// SPACING SCALE (strict adherence, no random values):
///   4, 8, 12, 16, 20, 24, 32, 40, 48, 64
///
/// BORDER RADIUS (frozen for v1.0):
///   Cards/Category Chips/Text Fields = 16
///   Buttons = 16
///   Search Bar = 18
///   Dialogs = 24
///   Bottom Sheet = 28
///   Pills = 999
///
/// ELEVATION:
///   Cards = 2
///   Pressed Card = 6
///   Dialogs = 8
///   Bottom Sheet = 12
class AppSpacing {
  AppSpacing._();

  // Spacing scale (frozen)
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;

  /// Standard horizontal screen edge padding.
  static const double screenH = 20;

  /// Standard vertical gap between sections.
  static const double sectionGap = 24;

  /// Standard vertical gap between cards in a list.
  static const double cardGap = 16;

  /// Horizontal page margin used by the design mockups.
  static const double containerMargin = 20;
}

class AppRadius {
  AppRadius._();

  // Frozen v1.0 radius values
  static const double card = 20;
  static const double panel = 20; // Alias for card
  static const double button = 16;
  static const double chip = 16;
  static const double input = 16;
  static const double searchBar = 18;
  static const double dialog = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

class AppElevation {
  AppElevation._();

  // Frozen v1.0 elevation values
  static const double card = 2;
  static const double cardPressed = 6;
  static const double dialog = 8;
  static const double sheet = 12;
}

class AppDurations {
  AppDurations._();

  // Frozen v1.0 animation durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration page = Duration(milliseconds: 320);

  // Special durations
  static const Duration press = Duration(milliseconds: 120);
  static const Duration wishlist = Duration(milliseconds: 180);
  static const Duration splash = Duration(milliseconds: 1400);
}

class AppCurves {
  AppCurves._();

  // Frozen v1.0 animation curves (no experimenting)
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeOut = Curves.easeOut;
}

/// Semantic colors that adapt to light/dark so we never hardcode
/// `Colors.red`, `Colors.green`, `Colors.amber` etc. in widget code.
extension AppSemanticColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Used for wishlist / love states.
  Color get loveColor =>
      isDark ? const Color(0xFFFF8A8A) : const Color(0xFFE5484D);

  /// Used for success / added-to-cart / "in cart" states.
  Color get successColor =>
      isDark ? const Color(0xFF7BD88F) : const Color(0xFF1F9D55);

  /// Used for ratings / stars.
  Color get ratingColor =>
      isDark ? const Color(0xFFFFD700) : const Color(0xFFE8A317);

  /// Soft success surface (banners, badges).
  Color get successSurface =>
      isDark ? const Color(0xFF143020) : const Color(0xFFE8F7EC);

  /// Soft love surface.
  Color get loveSurface =>
      isDark ? const Color(0xFF34171B) : const Color(0xFFFDECEE);

  /// Discount / sale accent.
  Color get discountColor =>
      isDark ? const Color(0xFFFFB088) : const Color(0xFFD64545);

  /// Muted icon color for empty image placeholders.
  Color get mutedIcon =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.28);

  /// Standard divider/stroke color.
  Color get hairline =>
      Theme.of(this).colorScheme.outline.withValues(alpha: 0.18);

  /// Tonal card stroke that works in both themes.
  Color get cardStroke =>
      isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8DDD4);
}
