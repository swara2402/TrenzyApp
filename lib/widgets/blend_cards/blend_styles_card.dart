import 'package:flutter/material.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';
import 'blend_card_decoration.dart';

class BlendStylesCard extends StatelessWidget {
  const BlendStylesCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final styles = results.sharedStyles;

    if (styles.isEmpty) {
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
                Icons.style_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shared Styles',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your fashion DNA overlaps here',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: styles.map((s) => _StyleChip(style: s)).toList(),
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
            Icons.style_rounded,
            size: 40,
            color: GlassColors.fg20,
          ),
          const SizedBox(height: 12),
          Text(
            'No shared styles yet',
            style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Style preferences will appear as you swipe more',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.style});

  final String style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.trenzyColors.emerald.withValues(alpha: 0.1),
            context.trenzyColors.primaryDim.withValues(alpha: 0.08),
            context.trenzyColors.emerald.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        border: Border.all(
          color: context.trenzyColors.emerald.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        style,
        style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700, color: context.trenzyColors.emerald),
      ),
    );
  }
}
