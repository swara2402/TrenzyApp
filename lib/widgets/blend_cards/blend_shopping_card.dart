import 'package:flutter/material.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';

class BlendShoppingCard extends StatelessWidget {
  const BlendShoppingCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final personality = _derivePersonality(results);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlassSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.trenzyColors.primary.withValues(alpha: 0.15),
            context.trenzyColors.emerald.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: context.trenzyColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shopping Personality',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your shared fashion identity',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: context.trenzyColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(GlassRadius.pill),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                personality.label,
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900, color: context.trenzyColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            personality.description,
            style: GlassTypography.body(fontSize: 14, color: context.trenzyColors.fg70, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: personality.traits.map((t) => _TraitChip(trait: t)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static _Personality _derivePersonality(BlendResults r) {
    final brandCount = r.sharedBrands?.length ?? 0;
    final styleCount = r.sharedStyles?.length ?? 0;
    final colourCount = r.sharedColours?.length ?? 0;
    final categoryCount = r.sharedCategories?.length ?? 0;
    final overlap = r.wardrobeOverlap ?? 0;
    final score = r.fashionScore ?? 0;

    if (brandCount >= 4 && score >= 60) {
      return _Personality(
        label: 'The Brand Curator',
        description:
            'You both value quality names and have a sharp eye for prestigious labels. Your shared taste in brands forms the foundation of your fashion connection.',
        traits: const ['Brand-conscious', 'Quality-driven', 'Luxury-leaning'],
      );
    }
    if (styleCount >= 4 && colourCount >= 3) {
      return _Personality(
        label: 'The Bold Experimenter',
        description:
            'You are not afraid to push boundaries. Your shared love for diverse styles and rich colours shows a fearless approach to fashion.',
        traits: const ['Creative', 'Trend-forward', 'Expressive'],
      );
    }
    if (categoryCount >= 3 && overlap > 5) {
      return _Personality(
        label: 'The Practical Stylist',
        description:
            'You both focus on versatility and real-world wearability. Your overlap shows a shared instinct for functional yet stylish pieces.',
        traits: const ['Practical', 'Versatile', 'Wearable'],
      );
    }
    if (brandCount >= 2 && styleCount >= 2) {
      return _Personality(
        label: 'The Balanced Shopper',
        description:
            'You mix brand awareness with personal style. Your fashion connection is built on a well-rounded appreciation for both labels and aesthetics.',
        traits: const ['Balanced', 'Style-aware', 'Thoughtful'],
      );
    }
    if (score >= 50) {
      return _Personality(
        label: 'The Fashion Forward',
        description:
            'Your high compatibility score reflects a deep alignment in fashion instincts. You just get each other\'s style.',
        traits: const ['Instinctive', 'Aligned', 'Confident'],
      );
    }

    return _Personality(
      label: 'The Rising Fashion Friend',
      description:
          'Your fashion connection is still growing. Keep discovering shared preferences by swiping on more products together.',
      traits: const ['Evolving', 'Curious', 'Open-minded'],
    );
  }
}

class _Personality {
  const _Personality({
    required this.label,
    required this.description,
    required this.traits,
  });

  final String label;
  final String description;
  final List<String> traits;
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.trait});

  final String trait;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.trenzyColors.emerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        border: Border.all(
          color: context.trenzyColors.emerald.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        trait,
        style: GlassTypography.meta(fontSize: 12, color: context.trenzyColors.emerald)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}