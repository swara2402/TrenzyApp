import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../providers/products_provider.dart';
import '../providers/wishlist_provider.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../utils/error_utils.dart';
import '../widgets/app_widgets.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final _filters = const ['All Items', 'Clothing', 'Accessories', 'Footwear'];
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final wishlistProductsAsync = ref.watch(wishlistProductsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sticky top app bar.
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: cs.surface.withValues(alpha: 0.0),
              elevation: 0,
              centerTitle: false,
              title: Text(
                'Saved',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => context.push(AppRoutes.search),
                  child: Text(
                    'See all',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),

            // Filter chips.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerMargin,
                  AppSpacing.xs,
                  AppSpacing.containerMargin,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final selected = _selectedFilter == index;
                      return TapScale(
                        onTap: () => setState(() => _selectedFilter = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: selected
                                ? null
                                : Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _filters[index],
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Content.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                0,
                AppSpacing.containerMargin,
                AppSpacing.xl,
              ),
              sliver: wishlistProductsAsync.when(
                loading: () => const _WishlistSkeleton(),
                error: (e, _) => SliverToBoxAdapter(
                  child: AsyncRetryErrorState(
                    title: 'Failed to load saved items',
                    message: friendlyErrorMessage(e),
                    onRetry: () {
                      ref.invalidate(wishlistProductsProvider);
                      ref.invalidate(wishlistProvider);
                    },
                  ),
                ),
                data: (products) {
                  final filtered = _filterProducts(products);

                  if (products.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: FriendlyEmptyState(
                          title: 'Nothing saved yet',
                          message:
                              'Explore trends and tap the heart on items you love.',
                          icon: Icons.favorite_outline_rounded,
                          actionLabel: 'Browse Products',
                          onActionPressed: () => context.push(AppRoutes.search),
                        ),
                      ),
                    );
                  }

                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: FriendlyEmptyState(
                          title: 'No items in this category',
                          message:
                              'Try a different filter or save more pieces.',
                          icon: Icons.filter_list_off_rounded,
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.68,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ProductCard(product: filtered[index]);
                    }, childCount: filtered.length),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    if (_selectedFilter == 0) return products;
    final filter = _filters[_selectedFilter].toLowerCase();
    return products.where((p) {
      final category = (p.category ?? '').toLowerCase();
      final subcategory = (p.subcategory ?? '').toLowerCase();
      final articleType = (p.articleType ?? '').toLowerCase();
      return category.contains(filter) ||
          subcategory.contains(filter) ||
          articleType.contains(filter);
    }).toList();
  }
}

class _WishlistSkeleton extends StatelessWidget {
  const _WishlistSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.68,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
        childCount: 4,
      ),
    );
  }
}
