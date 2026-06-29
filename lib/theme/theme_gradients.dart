import 'package:flutter/material.dart';

class AppGradients {
  /// Light mode background — soft white / ivory canvas.
  static LinearGradient light = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9F9F9), Color(0xFFF5F5F5), Color(0xFFF9F9F9)],
  );

  /// Dark mode background — deep charcoal with a subtle lower shift.
  static LinearGradient dark = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF121414), Color(0xFF0C0F0F), Color(0xFF121414)],
  );

  /// Primary peach CTA gradient used across both modes.
  static const LinearGradient peach = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9E80), Color(0xFFFF8A65)],
  );
}
