import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_model.dart';
import '../providers/wishlist_provider.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../widgets/section_states.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GlassSpacing.lg,
                8,
                GlassSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  SizedBox(width: 8),
                  DisplayText(
                    'Wishlist',
                    fontSize: 20,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
            Expanded(
              child: wishlistAsync.when(
                loading: () => Center(
                  child: LoadingSkeletonShimmer(height: 400, radius: 16),
                ),
                error: (e, _) => Center(
                  child: ErrorSection(
                    title: 'Couldn\u2019t load your wishlist',
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(wishlistProvider),
                  ),
                ),
                data: (state) {
                  if (!state.isLoaded) {
                    return Center(
                      child: LoadingSkeletonShimmer(height: 400, radius: 16),
                    );
                  }

                  final ids = state.productIds.toList();

                  if (ids.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.trenzyColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              child: Icon(
                                Icons.favorite_border_rounded,
                                size: 40,
                                color: context.trenzyColors.primary,
                              ),
                            ),
                            SizedBox(height: 20),
                            DisplayText(
                              'Nothing saved yet',
                              fontSize: 20,
                              weight: FontWeight.w700,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap the heart on any piece to keep it here for later inspiration.',
                              style: GlassTypography.body(
                                color: context.trenzyColors.mutedFg.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            GlowButton(
                              label: 'Discover Styles',
                              onTap: () => context.go(AppRoutes.discover),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final productsAsync = ref.watch(wishlistProductsProvider);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(wishlistProvider);
                      ref.invalidate(wishlistProductsProvider);
                    },
                    child: productsAsync.when(
                      loading: () => ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: ids.length,
                        itemBuilder: (_, _) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LoadingSkeletonShimmer(height: 88, radius: 12),
                        ),
                      ),
                      error: (_, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ErrorSection(
                            title: 'Couldn\u2019t load saved items',
                            message:
                                'Your saved pieces are unavailable right now.',
                            onRetry: () =>
                                ref.invalidate(wishlistProductsProvider),
                          ),
                        ],
                      ),
                      data: (products) {
                        if (products.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ErrorSection(
                                title: 'Couldn\u2019t load saved items',
                                message:
                                    'Your saved pieces are unavailable right now.',
                                onRetry: () =>
                                    ref.invalidate(wishlistProductsProvider),
                              ),
                            ],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _WishlistProductRow(
                              product: product,
                              onRemove: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(wishlistProvider.notifier)
                                    .toggle(product.id);
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistProductRow extends StatelessWidget {
  const _WishlistProductRow({required this.product, required this.onRemove});

  final ProductModel product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.productDetailsFor(product.id),
        extra: ProductDetailsRouteExtra(productId: product.id),
      ),
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 12),
        radius: 12,
        color: context.trenzyColors.graphite,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl:
                    ApiService.resolveImageUrl(product.imageUrl) ??
                    'https://placehold.co/400x600/1a1a2e/666.png?text=No+Image',
                width: 56,
                height: 72,
                fit: BoxFit.cover,
                memCacheWidth: 120,
                placeholder: (_, _) => Container(
                  width: 56,
                  height: 72,
                  color: context.trenzyColors.background,
                  child: Icon(
                    Icons.image_outlined,
                    color: context.trenzyColors.mutedFg,
                    size: 20,
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  width: 56,
                  height: 72,
                  color: context.trenzyColors.background,
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: context.trenzyColors.mutedFg,
                    size: 20,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.effectiveBrand.isNotEmpty)
                    Text(
                      product.effectiveBrand.toUpperCase(),
                      style: GlassTypography.body(
                        fontSize: 9,
                        weight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: context.trenzyColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (product.effectiveBrand.isNotEmpty) SizedBox(height: 2),
                  Text(
                    product.name,
                    style: GlassTypography.body(
                      fontSize: 14,
                      weight: FontWeight.w700,
                      color: context.trenzyColors.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '\u20B9${product.price.toStringAsFixed(0)}',
                    style: GlassTypography.body(
                      fontSize: 13,
                      weight: FontWeight.w800,
                      color: context.trenzyColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.favorite, color: context.trenzyColors.primary),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
