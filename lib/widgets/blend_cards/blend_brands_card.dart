import 'package:flutter/material.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';
import 'blend_card_decoration.dart';

class BlendBrandsCard extends StatelessWidget {
  const BlendBrandsCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final brands = results.sharedBrands ?? [];

    if (brands.isEmpty) {
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
                Icons.token_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shared Brands',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Brands you both love',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: brands.map((brand) => _BrandChip(brand: brand)).toList(),
            ),
          ),
          if (brands.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'and ${brands.length - 6} more...',
                style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.fg40),
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
            Icons.token_rounded,
            size: 40,
            color: GlassColors.fg20,
          ),
          const SizedBox(height: 12),
          Text(
            'No brands in common yet',
            style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Swipe on more products to discover shared brand preferences',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.trenzyColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        border: Border.all(
          color: context.trenzyColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        brand,
        style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700, color: context.trenzyColors.primary),
      ),
    );
  }
}
