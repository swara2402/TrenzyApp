import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';

class BlendOutfitCard extends StatelessWidget {
  const BlendOutfitCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final allProducts = _topScoredProducts(results.winners);

    if (allProducts.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlassSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.trenzyColors.emerald.withValues(alpha: 0.1),
            context.trenzyColors.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: context.trenzyColors.emerald.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.checkroom_rounded,
                size: 20,
                color: context.trenzyColors.emerald,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Shared Outfit',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Top picks you both love',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _outfitSlots.length,
              separatorBuilder: (_, a) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final slot = _outfitSlots[index];
                final product = index < allProducts.length ? allProducts[index] : null;
                return _OutfitSlot(
                  slotLabel: slot,
                  rankedProduct: product,
                  index: index,
                );
              },
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
        border: Border.all(
          color: GlassColors.glassBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checkroom_rounded,
            size: 40,
            color: GlassColors.fg20,
          ),
          const SizedBox(height: 12),
          Text(
            'No outfit picks yet',
            style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Start swiping to build your shared outfit',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<BlendRankedProduct> _topScoredProducts(
    List<BlendCategoryWinner> winners,
  ) {
    final list = <BlendRankedProduct>[];
    for (final w in winners) {
      list.addAll(w.products);
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}

const _outfitSlots = [
  'Top Wear',
  'Bottom Wear',
  'Footwear',
  'Accessory',
  'Outerwear',
];

class _OutfitSlot extends StatelessWidget {
  const _OutfitSlot({
    required this.slotLabel,
    required this.rankedProduct,
    required this.index,
  });

  final String slotLabel;
  final BlendRankedProduct? rankedProduct;
  final int index;

  @override
  Widget build(BuildContext context) {
    final rp = rankedProduct;
    final product = rp?.product;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.trenzyColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.trenzyColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: GlassTypography.meta(fontSize: 12, color: context.trenzyColors.primary)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          if (product != null && product.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36,
                height: 36,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, a) => Container(
                    color: context.trenzyColors.fg10,
                  ),
                  errorWidget: (_, a, b) => Container(
                    color: context.trenzyColors.fg10,
                    child: const Icon(Icons.image_outlined, size: 16),
                  ),
                ),
              ),
            ),
          if (product != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slotLabel,
                  style: GlassTypography.body(fontSize: 12, weight: FontWeight.w600, color: context.trenzyColors.mutedFg),
                ),
                Text(
                  product?.name ?? 'Swipe to discover',
                  style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (rp != null)
            Text(
              '${rp.matchScore}%',
              style: GlassTypography.buttonLabel(fontSize: 14, color: context.trenzyColors.primary)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }
}
