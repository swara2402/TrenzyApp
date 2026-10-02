import 'package:flutter/material.dart';

class AppGradients {
  /// Light mode background — soft alabaster / ivory canvas.
  static LinearGradient light = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF8F5), Color(0xFFF5EFEA), Color(0xFFFBF8F5)],
  );

  /// Dark mode background — deep espresso with subtle warm gradation.
  static LinearGradient dark = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF120F0E), Color(0xFF0D0B0A), Color(0xFF120F0E)],
  );

  /// Primary rose-gold CTA gradient used across both modes.
  static const LinearGradient roseGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE2A997), Color(0xFFC78977)],
  );

  /// Deprecated alias for backwards compatibility.
  static const LinearGradient peach = roseGold;
}
