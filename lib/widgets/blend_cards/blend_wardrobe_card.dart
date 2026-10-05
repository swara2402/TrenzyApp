import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/blend_model.dart';
import '../../theme/glass_theme.dart';
import 'blend_card_decoration.dart';

class BlendWardrobeCard extends StatelessWidget {
  const BlendWardrobeCard({
    super.key,
    required this.results,
  });

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    final overlap = results.wardrobeOverlap ?? 0;
    final allProducts = _allRecommendedProducts(results.recommendations);

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
                Icons.inventory_2_rounded,
                size: 20,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Wardrobe Overlap',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Items you both would rock',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 24),
          if (overlap > 0) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    '$overlap',
                    style: GlassTypography.display(fontSize: 64, weight: FontWeight.w900, color: context.trenzyColors.primary)
                        .copyWith(height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overlap == 1 ? 'shared item' : 'shared items',
                    style: GlassTypography.body(fontSize: 16, weight: FontWeight.w600, color: context.trenzyColors.mutedFg),
                  ),
                ],
              ),
            ),
            if (allProducts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: allProducts.length > 4 ? 4 : allProducts.length,
                  separatorBuilder: (_, a) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rp = allProducts[index];
                    return _OverlapProductRow(rankedProduct: rp);
                  },
                ),
              ),
              if (allProducts.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${allProducts.length - 4} more shared recommendations',
                    style: GlassTypography.body(fontSize: 12, weight: FontWeight.w700, color: context.trenzyColors.primary),
                  ),
                ),
            ],
          ] else ...[
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inventory_2_rounded,
          size: 40,
          color: GlassColors.fg20,
        ),
        const SizedBox(height: 12),
        Text(
          'No wardrobe overlap yet',
          style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Keep swiping to build shared fashion preferences',
          style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<BlendRankedProduct> _allRecommendedProducts(
    List<BlendRankedProduct>? recommendations,
  ) {
    if (recommendations == null) return [];
    final list = List<BlendRankedProduct>.from(recommendations);
    list.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    return list;
  }
}

class _OverlapProductRow extends StatelessWidget {
  const _OverlapProductRow({required this.rankedProduct});

  final BlendRankedProduct rankedProduct;

  @override
  Widget build(BuildContext context) {
    final p = rankedProduct.product;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: p?.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: p!.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, a) => Container(
                        color: context.trenzyColors.fg10,
                      ),
                      errorWidget: (_, a, b) => Container(
                        color: context.trenzyColors.fg10,
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: context.trenzyColors.fg30,
                        ),
                      ),
                    )
                  : Container(
                      color: context.trenzyColors.fg10,
                      child: Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: context.trenzyColors.fg30,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.name ?? '',
                  style: GlassTypography.body(fontSize: 14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  p?.brand ?? p?.category ?? '',
                  style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          ),
          Text(
            '${(rankedProduct.matchScore ?? 0).toInt()}%',
            style: GlassTypography.buttonLabel(fontSize: 14, color: context.trenzyColors.primary)
                .copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}