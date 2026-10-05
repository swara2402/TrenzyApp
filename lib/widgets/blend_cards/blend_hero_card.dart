import 'package:flutter/material.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';

class BlendHeroCard extends StatefulWidget {
  const BlendHeroCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  State<BlendHeroCard> createState() => _BlendHeroCardState();
}

class _BlendHeroCardState extends State<BlendHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _scaleIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.5, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.results;
    final scoreInt = (r.fashionScore ?? 0).toInt();
    final levelColor = _levelColor(scoreInt);
    final compatLevel = r.compatibilityLevel != null ? '${r.compatibilityLevel}' : '';

    return FadeTransition(
      opacity: _fadeIn,
      child: ScaleTransition(
        scale: _scaleIn,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(GlassSpacing.xl, GlassSpacing.xxl, GlassSpacing.xl, GlassSpacing.xxl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GlassRadius.card),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.trenzyColors.primary.withValues(alpha: 0.12),
                context.trenzyColors.emerald.withValues(alpha: 0.08),
                context.trenzyColors.primaryDim.withValues(alpha: 0.05),
                context.trenzyColors.primary.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: context.trenzyColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Fashion Match',
                style: GlassTypography.meta(fontSize: 12, color: context.trenzyColors.primary)
                    .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              if (compatLevel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                    border: Border.all(color: levelColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    compatLevel,
                    style: GlassTypography.meta(fontSize: 12, color: levelColor)
                        .copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.3),
                  ),
                ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (r.fashionScore ?? 0).toDouble()),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutQuart,
                builder: (context, value, _) {
                  return Text(
                    '${value.round()}%',
                    style: GlassTypography.display(fontSize: 72, weight: FontWeight.w900, color: levelColor)
                        .copyWith(height: 1),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'compatibility',
                style: GlassTypography.body(fontSize: 16, weight: FontWeight.w600, color: context.trenzyColors.mutedFg),
              ),
              const SizedBox(height: 16),
              Text(
                (r.memberCount ?? 0) > 2
                    ? "Based on your group's wishlists and purchase history"
                    : 'Based on your wishlists and purchase history',
                style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.fg50),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                height: 1,
                color: context.trenzyColors.glassBorder,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatTile(label: 'Members', value: '${r.memberCount ?? 0}'),
                  _StatTile(label: 'Swipes', value: '${r.totalSwipes ?? 0}'),
                  _StatTile(label: 'Brands', value: '${r.sharedBrands?.length ?? 0}'),
                  _StatTile(label: 'Overlap', value: '${r.wardrobeOverlap ?? 0}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 55) return Colors.blue;
    if (score >= 35) return Colors.orange;
    return Colors.red;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GlassTypography.body(fontSize: 12, weight: FontWeight.w600, color: context.trenzyColors.mutedFg),
        ),
      ],
    );
  }
}
