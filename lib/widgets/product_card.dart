import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../router/app_router.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/analytics_service_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_widgets.dart';

class ProductCard extends ConsumerStatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
    this.discountLabel,
  });

  final ProductModel product;
  final bool compact;

  /// Optional short label (e.g. "-20%") rendered as a discount badge on the
  /// image. Hidden when null.
  final String? discountLabel;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  Future<void> _toggleWishlist(bool currentlySaved) async {
    await ref.read(wishlistProvider.notifier).toggle(widget.product.id);

    await ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: currentlySaved ? 'wishlist_remove' : 'wishlist_add',
          parameters: {'product_id': widget.product.id},
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlySaved
                ? '${widget.product.name} removed from wishlist'
                : '${widget.product.name} added to wishlist',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final wishlistAsync = ref.watch(wishlistProvider);
    final wishlistIds = wishlistAsync.maybeWhen(
      data: (v) => v.productIds,
      orElse: () => const <String>[],
    );
    final isSaved = wishlistIds.contains(widget.product.id);
    final hasRating = widget.product.rating != null;

    final imageHeight = widget.compact ? 132.0 : 160.0;

    return TapScale(
      onTap: () {
        HapticFeedback.lightImpact(); // v1.0: haptic on open product
        ref.read(recentlyViewedProvider.notifier).add(widget.product.id);
        context.push(
          AppRoutes.productDetails,
          extra: ProductDetailsRouteExtra(productId: widget.product.id),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widget.compact ? 168 : null,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            color: cs.surfaceContainerLow.withValues(alpha: 0.6),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image block with badges + wishlist overlay
              Stack(
                children: [
                  Hero(
                    tag: 'product_${widget.product.id}_image',
                    // Keep the rounded card corners stable during flight.
                    createRectTween: (begin, end) =>
                        MaterialRectCenterArcTween(begin: begin, end: end),
                    flightShuttleBuilder:
                        (
                          context,
                          animation,
                          direction,
                          fromContext,
                          toContext,
                        ) {
                          final hero = fromContext.widget;
                          return _HeroImageShuttle(
                            animation: animation,
                            direction: direction,
                            child: hero is Hero
                                ? hero.child
                                : const SizedBox.shrink(),
                          );
                        },
                    child: Container(
                      height: imageHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        color: cs.surfaceContainerHighest,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          widget.product.imageUrl != null &&
                              widget.product.imageUrl!.isNotEmpty
                          ? Image.network(
                              widget.product.imageUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: widget.compact ? 360 : 600,
                              errorBuilder: (_, _, _) => _ImagePlaceholder(
                                size: widget.compact ? 36 : 44,
                              ),
                            )
                          : _ImagePlaceholder(size: widget.compact ? 36 : 44),
                    ),
                  ),
                  if (hasRating)
                    Positioned(
                      top: AppSpacing.xxs,
                      left: AppSpacing.xxs,
                      child: _RatingPill(rating: widget.product.rating!),
                    ),
                  if (widget.discountLabel != null)
                    Positioned(
                      top: hasRating ? 28 : AppSpacing.xxs,
                      left: AppSpacing.xxs,
                      child: _DiscountPill(label: widget.discountLabel!),
                    ),
                  Positioned(
                    top: AppSpacing.xxs,
                    right: AppSpacing.xxs,
                    child: _WishlistHeart(
                      isSaved: isSaved,
                      onTap: () => _toggleWishlist(isSaved),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Product name
              Text(
                widget.product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              // Brand
              if ((widget.product.brand ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.product.brand!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
              const Spacer(),
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.product.formattedPrice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.primaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.shopping_bag_rounded,
        size: size,
        color: context.mutedIcon,
      ),
    );
  }
}

class _HeroImageShuttle extends StatelessWidget {
  const _HeroImageShuttle({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final HeroFlightDirection direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Slight scale + fade to feel fluid.
    final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: t,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.02).animate(t),
        child: child,
      ),
    );
  }
}

class _WishlistHeart extends StatefulWidget {
  const _WishlistHeart({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  State<_WishlistHeart> createState() => _WishlistHeartState();
}

class _WishlistHeartState extends State<_WishlistHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.wishlist, // v1.0: 180ms
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    HapticFeedback.lightImpact(); // v1.0: haptic on wishlist
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // v1.0: Scale 0.8 → 1.15 → 1.0
    final scaleTween = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.8,
        ).chain(CurveTween(curve: AppCurves.easeOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.15,
        ).chain(CurveTween(curve: AppCurves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: AppCurves.easeOutCubic)),
        weight: 30,
      ),
    ]);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surface.withValues(alpha: 0.85),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: _controller.drive(scaleTween),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.isSaved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(widget.isSaved),
              size: 16,
              color: widget.isSaved
                  ? context.loveColor
                  : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: context.ratingColor),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.discountColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
