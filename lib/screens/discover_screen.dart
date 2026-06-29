import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/products_provider.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_widgets.dart';
import '../widgets/product_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // v1.0: Staggered reveal animation for product grid
  Widget _reveal(int index, Widget child) {
    final delay = (index % 12) * 0.06;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        final v = (value - delay).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 10),
            child: Transform.scale(scale: 0.98 + (eased * 0.02), child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              onToggleTheme: widget.onToggleTheme,
              leading: Icons.menu_rounded,
              trailing: Icons.notifications_outlined,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  // Hero greeting
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi Sam 👋',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Let's find your vibe today.",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: SearchField(
                          controller: _searchController,
                          hintText: 'Search for products, brands...',
                          onTap: () => context.push(AppRoutes.search),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: cs.onSurface,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Featured banner
                  _FeaturedBanner(onTap: () => context.push(AppRoutes.search)),
                  const SizedBox(height: AppSpacing.lg),
                  // Trending Now
                  SectionHeader(
                    title: 'Trending Now',
                    action: 'See all',
                    onAction: () => context.push(AppRoutes.trends),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ]),
              ),
            ),
            // Trending horizontal list
            const SliverToBoxAdapter(child: _TrendingProductsRow()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.lg,
                AppSpacing.containerMargin,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recommended for You',
                  action: 'See all',
                  onAction: () => context.push(AppRoutes.search),
                ),
              ),
            ),
            // Recommended / all products grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
              ),
              sliver: productsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: ProductGridSkeleton(itemCount: 4),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: AsyncRetryErrorState(
                    title: 'Failed to load products',
                    message: e.toString(),
                    onRetry: () => ref.invalidate(productsProvider(null)),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: FriendlyEmptyState(
                          title: 'No products yet',
                          message:
                              'Browse the catalog to discover curated picks.',
                          icon: Icons.shopping_bag_rounded,
                          actionLabel: 'Browse Products',
                        ),
                      ),
                    );
                  }
                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _reveal(index, ProductCard(product: products[index])),
                      childCount: products.length,
                    ),
                  );
                },
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [cs.surfaceContainerHighest, cs.surfaceContainer],
          ),
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?auto=format&fit=crop&w=800&q=80',
            ),
            fit: BoxFit.cover,
            opacity: 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'EXCLUSIVE DROP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'THE CHROME\nCOLLECTION',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9E80), Color(0xFFFF8A65)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Shop Now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryFixed,
                      ),
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
}

class _TrendingProductsRow extends ConsumerWidget {
  Widget _reveal(int index, Widget child) {
    final delay = (index % 12) * 0.06;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        final v = (value - delay).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(v);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 10),
            child: Transform.scale(scale: 0.98 + (eased * 0.02), child: child),
          ),
        );
      },
    );
  }

  const _TrendingProductsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider(null));

    return productsAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        final trending = products.take(6).toList();
        return SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.containerMargin,
            ),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == trending.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: 160,
                  child: _reveal(
                    index,
                    ProductCard(product: trending[index], compact: true),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
