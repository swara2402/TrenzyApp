import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/providers/trends_provider.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/widgets/section_states.dart';

class InspoScreen extends ConsumerWidget {
  const InspoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(discoverRecommendedProductsProvider);
    final trendingAsync = ref.watch(
      trendingProductsProvider(TrendingParams(timeframe: 'daily', limit: 8)),
    );
    final creatorsAsync = ref.watch(discoverTrendingCreatorsProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discoverRecommendedProductsProvider);
          ref.invalidate(
            trendingProductsProvider(
              TrendingParams(timeframe: 'daily', limit: 8),
            ),
          );
          ref.invalidate(discoverTrendingCreatorsProvider);
        },
        color: context.trenzyColors.primary,
        backgroundColor: context.trenzyColors.graphite,
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSPIRATION',
                      style: TextStyle(
                        fontFamily: GlassTypography.bodyFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    DisplayText('Get Inspired', fontSize: 24),
                    SizedBox(height: 4),
                    Text(
                      'Curated styles, trending looks, and style creators',
                      style: GlassTypography.body(
                        color: context.trenzyColors.mutedFg,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Creators Section ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.trenzyColors.emerald,
                            context.trenzyColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Style Creators',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.allCreators),
                      child: Text(
                        'See All',
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            creatorsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 4,
                    separatorBuilder: (_, _) => SizedBox(width: 16),
                    itemBuilder: (_, _) => LoadingSkeletonShimmer(
                      height: 100,
                      width: 80,
                      radius: 40,
                    ),
                  ),
                ),
              ),
              error: (_, _) => ErrorSectionSliver(
                title: 'Couldn\u2019t load creators',
                message: 'Trending creators are unavailable right now.',
                onRetry: () => ref.invalidate(discoverTrendingCreatorsProvider),
              ),
              data: (creators) {
                if (creators.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 80,
                      child: Center(
                        child: Text(
                          'No creators to follow yet',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: creators.length,
                      separatorBuilder: (_, _) => SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final creator = creators[index];
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.userProfile,
                            extra: creator.id,
                          ),
                          child: SizedBox(
                            width: 80,
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        context.trenzyColors.primary,
                                        context.trenzyColors.emerald,
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        context.trenzyColors.graphite,
                                    backgroundImage: NetworkImage(creator.avatarUrl),
                                    child: null,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  creator.name,
                                  style: TextStyle(
                                    color: context.trenzyColors.foreground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // ── Trending Looks Section ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.trenzyColors.crimson,
                            context.trenzyColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Trending Looks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            trendingAsync.when(
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 3,
                    separatorBuilder: (_, _) => SizedBox(width: 12),
                    itemBuilder: (_, _) => LoadingSkeletonShimmer(
                      height: 200,
                      width: 140,
                      radius: 16,
                    ),
                  ),
                ),
              ),
              error: (_, _) => ErrorSectionSliver(
                title: 'Couldn\u2019t load trending looks',
                message: 'Trending looks are unavailable right now.',
                onRetry: () => ref.invalidate(
                  trendingProductsProvider(
                    TrendingParams(timeframe: 'daily', limit: 8),
                  ),
                ),
              ),
              data: (trends) {
                if (trends.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No trending looks yet',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: trends.length,
                      separatorBuilder: (_, _) => SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final trend = trends[index];
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.productDetailsFor(trend.productId),
                            extra: ProductDetailsRouteExtra(
                              productId: trend.productId,
                            ),
                          ),
                          child: SizedBox(
                            width: 140,
                            child: GlassContainer(
                              color: context.trenzyColors.graphite,
                              radius: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child:
                                              trend.imageUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          16,
                                                        ),
                                                      ),
                                                  child: CachedNetworkImage(
                                                    imageUrl: trend.imageUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                              color: Colors
                                                                  .grey[900],
                                                            ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          color:
                                                              Colors.grey[900],
                                                          child: Icon(
                                                            Icons
                                                                .image_outlined,
                                                            color: context
                                                                .trenzyColors
                                                                .mutedFg,
                                                          ),
                                                        ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey[900],
                                                  child: Icon(
                                                    Icons.image_outlined,
                                                    color: context
                                                        .trenzyColors
                                                        .mutedFg,
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context
                                                  .trenzyColors
                                                  .primary
                                                  .withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'HOT',
                                              style: TextStyle(
                                                color: context
                                                    .trenzyColors
                                                    .primaryFg,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      10,
                                      8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trend.productName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                context.trenzyColors.foreground,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          trend.category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: context.trenzyColors.mutedFg,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // ── Recommended For You Section ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.trenzyColors.primary,
                            context.trenzyColors.primary.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Recommended For You',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            recommendedAsync.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LoadingSkeletonShimmer(height: 120, radius: 16),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (_, _) => ErrorSectionSliver(
                title: 'Couldn\u2019t load picks for you',
                message: 'Your personalized picks are unavailable right now.',
                onRetry: () =>
                    ref.invalidate(discoverRecommendedProductsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Start exploring to get personalized picks',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final rec = products[index];
                      return _InspoProductCard(
                        product: rec.product,
                        onTap: () => context.push(
                          AppRoutes.productDetailsFor(rec.product.id),
                          extra: ProductDetailsRouteExtra(
                            productId: rec.product.id,
                          ),
                        ),
                      );
                    }, childCount: products.length),
                  ),
                );
              },
            ),

            SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _InspoProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _InspoProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        color: context.trenzyColors.graphite,
        radius: 16,
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: product.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.image_outlined,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.broken_image,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: Icon(
                          Icons.image_outlined,
                          color: context.trenzyColors.mutedFg,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      '\u20B9${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
