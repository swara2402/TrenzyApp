import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../providers/wishlist_provider.dart';
import '../theme/glass_theme.dart';

enum ProductCardVariant { standard, overlay, compact }

class ProductCard extends ConsumerStatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.heroTagSuffix,
    this.onTap,
    this.compact = false,
    this.variant = ProductCardVariant.standard,
    this.customPriceText,
  });

  final ProductModel product;
  final String? heroTagSuffix;
  final VoidCallback? onTap;
  final bool compact;
  final ProductCardVariant variant;
  final String? customPriceText;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isWishlisted(String productId) =>
      ref.watch(wishlistProvider.select((w) => w.valueOrNull?.contains(productId) ?? false));

  @override
  Widget build(BuildContext context) {
    switch (widget.variant) {
      case ProductCardVariant.overlay:
        return _buildOverlay();
      case ProductCardVariant.compact:
        return _buildCompact();
      case ProductCardVariant.standard:
        return _buildStandard();
    }
  }

  Widget _buildStandard() {
    final isDark = context.isDark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: 'product_${widget.product.id}${widget.heroTagSuffix ?? ''}',
        child: Container(
          decoration: BoxDecoration(
            color: context.trenzyColors.background,
            borderRadius: BorderRadius.circular(GlassRadius.card),
            border: Border.all(color: context.trenzyColors.glassBorder.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                        child: widget.product.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: ApiService.resolveImageUrl(widget.product.imageUrl) ?? widget.product.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                memCacheWidth: 400,
                                placeholder: (context, url) => SizedBox(
                                  width: double.infinity,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: context.trenzyColors.graphite,
                                  child: Icon(Icons.shopping_bag_rounded, size: 48, color: context.trenzyColors.foreground.withValues(alpha: 0.3)),
                                ),
                              )
                            : Container(
                                color: context.trenzyColors.graphite,
                                child: Icon(Icons.shopping_bag_rounded, size: 48, color: context.trenzyColors.foreground.withValues(alpha: 0.3)),
                              ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: TapScale(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            ref.read(wishlistProvider.notifier).toggle(widget.product.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Saved to wishlist'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: context.trenzyColors.emerald,
                              ),
                            );
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: GlassGradients.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: context.trenzyColors.primary.withAlpha(77),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_add_outlined, size: 14, color: context.trenzyColors.primaryFg),
                                  SizedBox(width: 4),
                                  Text(
                                    'SAVE',
                                    style: TextStyle(
                                      fontFamily: GlassTypography.bodyFont,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: context.trenzyColors.primaryFg,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(GlassSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: GlassTypography.body(
                            fontSize: 14,
                            weight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    Text(
                      widget.customPriceText ?? '${widget.product.effectivePrice}',
                          style: GlassTypography.body(
                            fontSize: 14,
                            weight: FontWeight.w800,
                            color: context.trenzyColors.primary,
                          ),
                        ),
                    ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 11, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          widget.product.rating.toStringAsFixed(1),
                          style: GlassTypography.body(fontSize: 10, color: context.trenzyColors.mutedFg),
                        ),
                      ],
                    ),
                  ],
                    // Show recommendation reason if available
                    if (widget.product.reason.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        widget.product.reason,
                        style: GlassTypography.body(fontSize: 10, color: context.trenzyColors.mutedFg.withValues(alpha: 0.8)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        LikeBounce(
                          isLiked: _isWishlisted(widget.product.id),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(wishlistProvider.notifier)
                                .toggle(widget.product.id);
                          },
                          child: Icon(
                            _isWishlisted(widget.product.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color: _isWishlisted(widget.product.id)
                                ? context.trenzyColors.crimson
                                : context.trenzyColors.mutedFg,
                          ),
                        ),
                        SizedBox(width: 10),
                        SaveSlide(
                          isSaved: _isWishlisted(widget.product.id),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(wishlistProvider.notifier)
                                .toggle(widget.product.id);
                          },
                          child: Icon(
                            _isWishlisted(widget.product.id)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                            color: _isWishlisted(widget.product.id)
                                ? context.trenzyColors.primary
                                : context.trenzyColors.mutedFg,
                          ),
                        ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: ApiService.resolveImageUrl(widget.product.imageUrl) ?? widget.product.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 400,
              placeholder: (context, url) => Container(
                color: context.trenzyColors.surfaceContainer,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.trenzyColors.primary,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: context.trenzyColors.surfaceContainer,
                child: Icon(Icons.shopping_bag_rounded, size: 48, color: context.trenzyColors.mutedFg),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.effectiveBrand.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.trenzyColors.primary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.product.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.trenzyColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(ApiService.resolveImageUrl(widget.product.imageUrl) ?? widget.product.imageUrl),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: context.trenzyColors.glassBorder),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.product.effectiveBrand.toUpperCase(),
            style: TextStyle(
              color: context.trenzyColors.mutedFg.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            widget.product.name,
            style: TextStyle(
              color: context.trenzyColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            widget.customPriceText ?? '${widget.product.effectivePrice}',
            style: TextStyle(
              color: context.trenzyColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Show recommendation reason if available in compact mode
          if (widget.product.reason.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              widget.product.reason,
              style: TextStyle(
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}