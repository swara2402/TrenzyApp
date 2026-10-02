import 'dart:convert';

import 'package:flutter/material.dart';

/// Offline-capable placeholder background that never touches the network.
///
/// Draws a subtle branded gradient with centered text, so screens never block
/// on external placeholder services (e.g. placehold.co) or fail to render
/// offline. Prefer this over an encoded-image placeholder: the standard
/// Flutter codec cannot decode SVG, so data-URI SVGs must not be passed to
/// `Image.network`/`Image.memory`.
Widget offlinePlaceholderBackground({
  required String text,
  Color? background,
  Color? foreground,
}) {
  final bg = background ?? const Color(0xFF1A1A2E);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bg,
          Color.lerp(bg, Colors.black, 0.25)!,
          Color.lerp(bg, Colors.black, 0.4)!,
        ],
      ),
    ),
    child: Center(
      child: Text(
        text,
        style: TextStyle(
          color: (foreground ?? const Color(0xFF999999)).withValues(alpha: 0.35),
          fontSize: 96,
          fontWeight: FontWeight.w800,
          letterSpacing: 12,
        ),
      ),
    ),
  );
}

/// Base64-encoded SVG data URI.
///
/// NOTE: this renders only through a decoder that supports data URIs or SVG
/// (e.g. `flutter_svg`, or HTML `<img>`). It must NOT be passed to
/// `Image.network`/`Image.memory`, which only understand raster formats.
String placeholderImage({
  required int width,
  required int height,
  String text = 'No Image',
  String bg = '1a1a2e',
  String fg = '666',
}) {
  final encodedText = Uri.encodeComponent(text);
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">'
      '<rect fill="%23$bg" width="$width" height="$height"/>'
      '<text fill="%23$fg" font-family="sans-serif" font-size="48" '
      'text-anchor="middle" x="${width ~/ 2}" y="${height ~/ 2 + 16}">'
      '$encodedText</text></svg>';
  return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
}
