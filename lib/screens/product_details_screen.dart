import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../providers/products_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/analytics_service_provider.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import '../widgets/app_widgets.dart';

/// Full-width hero image with a bottom gradient fade.
class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (context, error, stackTrace) => _placeholder(cs),
            )
          else
            _placeholder(cs),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  cs.surface,
                  cs.surface.withValues(alpha: 0.0),
                  cs.surface.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          size: 72,
          color: cs.onSurface.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

/// Circular glass action button used in the floating header.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 22, color: cs.onSurface),
      ),
    );
  }
}

/// Selectable size chip.
class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapScale(
      onTap: onSelected,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: selected ? peachGradient(context) : null,
          color: selected ? null : cs.surfaceContainerLow,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : cs.outlineVariant.withValues(alpha: 0.45),
            width: selected ? 0 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected
                ? (isDark ? const Color(0xFF0C0F0F) : const Color(0xFF2D2D2D))
                : cs.onSurface,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Trust badge pill used in the product details bento.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton that matches the new product detail layout.
class _ProductDetailsLoadingSkeleton extends StatelessWidget {
  const _ProductDetailsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 4 / 5),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.containerMargin,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                const LoadingSkeletonShimmer(
                  height: 16,
                  width: 120,
                  radius: AppRadius.chip,
                ),
                const SizedBox(height: AppSpacing.sm),
                const LoadingSkeletonShimmer(
                  height: 28,
                  width: double.infinity,
                  radius: AppRadius.input,
                ),
                const SizedBox(height: AppSpacing.sm),
                const LoadingSkeletonShimmer(
                  height: 16,
                  width: 160,
                  radius: AppRadius.chip,
                ),
                const SizedBox(height: AppSpacing.lg),
                const LoadingSkeletonShimmer(
                  height: 32,
                  width: 140,
                  radius: AppRadius.input,
                ),
                const SizedBox(height: AppSpacing.xl),
                const LoadingSkeletonShimmer(
                  height: 56,
                  width: double.infinity,
                  radius: AppRadius.input,
                ),
                const SizedBox(height: AppSpacing.xl),
                LoadingSkeletonShimmer(height: 120, radius: AppRadius.card),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.onToggleTheme,
    required this.productId,
  });

  final VoidCallback onToggleTheme;
  final String productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _selectedSizeIndex = 2; // Default to UK 8.
  final _sizes = const ['6', '7', '8', '9', '10'];

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailsProvider(widget.productId));
    final wishlistAsync = ref.watch(wishlistProvider);

    /// Track product view for recently viewed and analytics.
    ref.listen(productDetailsProvider(widget.productId), (prev, next) {
      next.whenData((product) {
        ref.read(recentlyViewedProvider.notifier).add(product.id);
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: 'product_view',
              parameters: {
                'product_id': product.id,
                'source': 'product_details',
              },
            );
      });
    });

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    const bottomBarHeight = 96.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: productAsync.when(
        loading: () => const _ProductDetailsLoadingSkeleton(),
        error: (e, _) => AsyncRetryErrorState(
          title: 'Failed to load product',
          message: friendlyErrorMessage(e),
          onRetry: () =>
              ref.invalidate(productDetailsProvider(widget.productId)),
        ),
        data: (product) {
          final wishlistIds = wishlistAsync.maybeWhen(
            data: (v) => v.productIds,
            orElse: () => const <String>[],
          );
          final isSaved = wishlistIds.contains(product.id);
          final isWishlistLoading = wishlistAsync.maybeWhen(
            loading: () => true,
            orElse: () => false,
          );

          final originalPrice = product.price != null && product.price! > 0
              ? (product.price! * 1.45).ceilToDouble()
              : null;
          final discountPercent = originalPrice != null
              ? ((1 - product.price! / originalPrice) * 100).round()
              : null;

          return Stack(
            children: [
              // Scrollable content.
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'product_${product.id}_image',
                        createRectTween: (begin, end) =>
                            MaterialRectCenterArcTween(begin: begin, end: end),
                        child: _ProductHero(imageUrl: product.imageUrl),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.containerMargin,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand badge.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  (product.brand ?? 'PREMIUM SELECTION')
                                      .toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.08,
                                      ),
                                ),
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              // Title & rating.
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.15,
                                          ),
                                    ),
                                  ),
                                  if (product.rating != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.chip,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: context.ratingColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            product.rating!.toStringAsFixed(1),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              if (product.rating != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '128 Reviews',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),

                              const SizedBox(height: AppSpacing.md),

                              // Pricing.
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    product.formattedPrice,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  if (originalPrice != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '₹${originalPrice.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '($discountPercent% OFF)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: context.discountColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              // Trust badges.
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: const [
                                    _TrustBadge(
                                      icon: Icons.local_shipping_outlined,
                                      label: 'Free Express Shipping',
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    _TrustBadge(
                                      icon: Icons.verified_user_outlined,
                                      label: 'Original Product',
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.xl),

                              // Size selector.
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SELECT SIZE (UK)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(letterSpacing: 0.08),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Size guide coming soon.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Size Chart',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.md,
                                runSpacing: AppSpacing.sm,
                                children: List.generate(_sizes.length, (index) {
                                  return _SizeChip(
                                    label: _sizes[index],
                                    selected: _selectedSizeIndex == index,
                                    onSelected: () {
                                      setState(
                                        () => _selectedSizeIndex = index,
                                      );
                                    },
                                  );
                                }),
                              ),

                              const SizedBox(height: AppSpacing.xl),

                              // Product details bento.
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Product Details',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _productDescription(product),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            height: 1.55,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.md),

                              // Spec bullet list.
                              Column(
                                children: [
                                  _specRow('Breathable Mesh'),
                                  _specRow('Impact Cushioning'),
                                  _specRow('Reinforced Heel'),
                                  _specRow('Vibrant Peach Sole'),
                                ],
                              ),

                              // Tags (if available).
                              if (product.tags != null &&
                                  product.tags!.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xl),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: product.tags!.map((tag) {
                                    return Chip(
                                      label: Text(tag),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow,
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withValues(alpha: 0.3),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // Bottom safe padding for fixed action bar.
                              SizedBox(
                                height:
                                    bottomBarHeight +
                                    bottomPadding +
                                    AppSpacing.lg,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating glass header.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.xs,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            Row(
                              children: [
                                _WishlistHeaderButton(
                                  isSaved: isSaved,
                                  isLoading: isWishlistLoading,
                                  onToggle: () => _toggleWishlist(ref, product),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                _GlassIconButton(
                                  icon: Icons.share_outlined,
                                  onPressed: () => _shareProduct(product),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                _GlassIconButton(
                                  icon:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  onPressed: widget.onToggleTheme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom action bar.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.containerMargin,
                        AppSpacing.md,
                        AppSpacing.containerMargin,
                        AppSpacing.md + bottomPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.sheet),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TapScale(
                              onTap: () => _addToCart(product),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add to Cart',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: TapScale(
                              onTap: () => _buyNow(product),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: peachGradient(context),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF9E80,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Buy Now',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: const Color(0xFF2D2D2D),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.02,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _specRow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _productDescription(ProductModel product) {
    if (product.usage != null && product.usage!.isNotEmpty) {
      return 'Engineered for ${product.usage!.toLowerCase()}. The ${product.name} combines premium materials with a street-ready silhouette for all-day comfort and standout style.';
    }
    return 'Elevate your street style with the ${product.name}. Crafted with premium materials and a modern silhouette, this piece is built for those who do not compromise on style or exclusivity.';
  }

  Future<void> _toggleWishlist(WidgetRef ref, ProductModel product) async {
    final wishlistAsync = ref.read(wishlistProvider);
    final wasSaved = wishlistAsync.maybeWhen(
      data: (v) => v.productIds.contains(product.id),
      orElse: () => false,
    );

    await ref.read(wishlistProvider.notifier).toggle(product.id);
    ref.invalidate(wishlistProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasSaved
              ? '${product.name} removed from saved'
              : '${product.name} added to saved',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    await ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: wasSaved ? 'wishlist_remove' : 'wishlist_add',
          parameters: {'product_id': product.id},
        );
  }

  void _shareProduct(ProductModel product) {
    final text =
        'Check out ${product.name} on Trenzy! ${product.formattedPrice}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product link copied to clipboard.')),
    );
  }

  void _addToCart(ProductModel product) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} added to cart.')));
    ref
        .read(analyticsServiceProvider)
        .logEvent(name: 'add_to_cart', parameters: {'product_id': product.id});
  }

  void _buyNow(ProductModel product) {
    final link = product.affiliateLinks;
    if (link != null && link.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: link));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Affiliate link copied to clipboard.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout is disabled for beta.')),
      );
    }
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: 'buy_now_tapped',
          parameters: {'product_id': product.id},
        );
  }
}

/// Header wishlist button with loading / filled states.
class _WishlistHeaderButton extends StatelessWidget {
  const _WishlistHeaderButton({
    required this.isSaved,
    required this.isLoading,
    required this.onToggle,
  });

  final bool isSaved;
  final bool isLoading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapScale(
      onTap: isLoading ? null : onToggle,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSaved
                ? context.loveColor.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              )
            : Icon(
                isSaved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 22,
                color: isSaved ? context.loveColor : cs.onSurface,
              ),
      ),
    );
  }
}
