import 'package:flutter/material.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';
import 'blend_card_decoration.dart';

class BlendColoursCard extends StatelessWidget {
  const BlendColoursCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  static const _colourMap = <String, Color>{
    'black': Color(0xFF1A1A1A),
    'white': Color(0xFFF5F5F5),
    'red': Color(0xFFD32F2F),
    'blue': Color(0xFF1565C0),
    'green': Color(0xFF2E7D32),
    'yellow': Color(0xFFFBC02D),
    'pink': Color(0xFFD81B60),
    'purple': Color(0xFF6A1B9A),
    'orange': Color(0xFFE65100),
    'brown': Color(0xFF5D4037),
    'grey': Color(0xFF616161),
    'gray': Color(0xFF616161),
    'navy': Color(0xFF0D2137),
    'beige': Color(0xFFE8D5B7),
    'cream': Color(0xFFFFFDD0),
    'maroon': Color(0xFF800000),
    'teal': Color(0xFF00695C),
    'olive': Color(0xFF827717),
    'coral': Color(0xFFFF6F61),
    'mint': Color(0xFF98FF98),
    'lavender': Color(0xFFB39DDB),
    'gold': Color(0xFFFFD700),
    'silver': Color(0xFFC0C0C0),
  };

  static Color _resolveColour(String name) {
    final lower = name.toLowerCase().trim();
    for (final entry in _colourMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    final colours = results.sharedColours;

    if (colours.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlassSpacing.xl),
      decoration: kPanelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shared Colours',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Colours that define your palette',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colours.map((c) => _ColourChip(colour: c)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlassSpacing.xl),
      decoration: BoxDecoration(
        color: GlassColors.graphite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(GlassRadius.card),
        border: Border.all(color: GlassColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.palette_rounded,
            size: 40,
            color: GlassColors.fg20,
          ),
          const SizedBox(height: 12),
          Text(
            'No shared colours yet',
            style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Colour preferences will appear as you discover more together',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


}

class _ColourChip extends StatelessWidget {
  const _ColourChip({required this.colour});

  final String colour;

  @override
  Widget build(BuildContext context) {
    final resolved = BlendColoursCard._resolveColour(colour);
    final isLight = resolved.computeLuminance() > 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        border: Border.all(color: resolved.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: resolved,
              shape: BoxShape.circle,
              border: Border.all(
                color: isLight ? context.trenzyColors.fg15 : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            colour,
            style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
