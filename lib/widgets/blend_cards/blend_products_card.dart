import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';
import 'blend_card_decoration.dart';

class BlendProductsCard extends StatelessWidget {
  const BlendProductsCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final allProducts = _flattenRecommendations(results.recommendations);

    if (allProducts.isEmpty) {
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
                Icons.recommend_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommended For You',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Top picks based on your shared taste',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: allProducts.length > 8 ? 8 : allProducts.length,
              separatorBuilder: (_, a) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _ProductRow(rankedProduct: allProducts[index]);
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
        border: Border.all(color: GlassColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.recommend_rounded,
            size: 40,
            color: GlassColors.fg20,
          ),
          const SizedBox(height: 12),
          Text(
            'No recommendations yet',
            style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Swipe on products together to get personalized recommendations',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  List<BlendRankedProduct> _flattenRecommendations(
    Map<String, List<BlendRankedProduct>> recommendations,
  ) {
    final list = <BlendRankedProduct>[];
    for (final entry in recommendations.entries) {
      list.addAll(entry.value);
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.rankedProduct});

  final BlendRankedProduct rankedProduct;

  @override
  Widget build(BuildContext context) {
    final p = rankedProduct.product;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: p.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, a) => Container(
                        color: context.trenzyColors.fg10,
                      ),
                      errorWidget: (_, a, b) => Container(
                        color: context.trenzyColors.fg10,
                        child: Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: context.trenzyColors.fg30,
                        ),
                      ),
                    )
                  : Container(
                      color: context.trenzyColors.fg10,
                      child: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: context.trenzyColors.fg30,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [p.effectiveBrand, p.effectivePrice]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: rankedProduct.matchScore >= 70
                  ? Colors.green.withValues(alpha: 0.1)
                  : context.trenzyColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(GlassRadius.pill),
            ),
            child: Text(
              '${rankedProduct.matchScore}%',
              style: GlassTypography.meta(fontSize: 12, color: rankedProduct.matchScore >= 70 ? Colors.green : context.trenzyColors.primary)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
