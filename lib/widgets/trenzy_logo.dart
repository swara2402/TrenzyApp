import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Trenzy brand mark — rendered from the app logo asset.
class TrenzyLogo extends StatelessWidget {
  const TrenzyLogo({
    super.key,
    this.size = 120,
    this.wordmark = true,
    this.tagline = false,
    this.color,
    this.glow = false,
  });

  final double size;
  final bool wordmark;
  final bool tagline;
  final Color? color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = color ?? theme.colorScheme.primary;

    Widget logoWidget = Image.asset(
      'logo/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (glow) {
      logoWidget = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.6,
            height: size * 1.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  brandColor.withValues(alpha: 0.28),
                  brandColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          logoWidget,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        if (wordmark) ...[
          const SizedBox(height: 18),
          Container(
            width: size * 0.62,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  brandColor.withValues(alpha: 0.0),
                  brandColor.withValues(alpha: 0.9),
                  brandColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TRENZY',
            style: GoogleFonts.plusJakartaSans(
              fontSize: size * 0.26,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: brandColor,
            ),
          ),
        ],
        if (tagline) ...[
          const SizedBox(height: 10),
          Text(
            'Curated by taste. Inspired by you.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.4,
              color: brandColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}
