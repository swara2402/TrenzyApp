import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../router/app_router.dart';
import '../providers/products_provider.dart';
import '../providers/discover_providers.dart';
import '../providers/trends_provider.dart';
import '../providers/auth_provider.dart' as auth_p;
import '../providers/wardrobe_provider.dart';
import '../models/wardrobe_model.dart';
import '../models/product_model.dart';
import '../widgets/product_card.dart';
import '../widgets/section_states.dart';
import '../widgets/cart_badge_button.dart';
import '../theme/glass_theme.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(auth_p.authProvider).valueOrNull;
    final avatarUrl = user?.avatarUrl;
    final userName = user?.name ?? 'U';

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discoverCampaignProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(
            trendingProductsProvider(
              TrendingParams(timeframe: 'daily', limit: 10),
            ),
          );
          ref.invalidate(productsProvider((category: null)));
          ref.invalidate(discoverRecommendedProductsProvider);
          ref.invalidate(discoverSwipeProductsProvider);
          ref.invalidate(personaProvider);
        },
        color: context.trenzyColors.primary,
        backgroundColor: context.trenzyColors.graphite,
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF2D2A21),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              (userName.isNotEmpty ? userName[0] : 'U')
                                  .toUpperCase(),
                              style: TextStyle(
                                color: context.trenzyColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Trenzy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.primary,
                        letterSpacing: -1,
                      ),
                    ),
                    Spacer(),
                    CartBadgeButton(),
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: context.trenzyColors.mutedFg,
                      ),
                      onPressed: () => context.push(AppRoutes.notifications),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    _buildSearchAndFilter(context),
                    SizedBox(height: 20),
                    _CampaignBanner(),
                    SizedBox(height: 24),
                    _SwipeDiscoveryPreview(),
                    SizedBox(height: 24),
                    _PersonaSection(),
                    SizedBox(height: 24),
                    _CategoryChips(),
                    SizedBox(height: 32),
                    _TrendingProducts(),
                    SizedBox(height: 32),
                    _RecommendedSection(),
                    SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassSearchBar(
            hintText: 'Search brands, styles, creators...',
            readOnly: true,
            onTap: () => context.push(AppRoutes.search),
          ),
        ),
        SizedBox(width: 12),
        GestureDetector(
          onTap: () => _buildFilterBottomSheet(context),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.trenzyColors.graphite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune, color: context.trenzyColors.mutedFg),
          ),
        ),
      ],
    );
  }

  void _buildFilterBottomSheet(BuildContext context) {
    String? selectedCategory;
    String sortBy = 'relevance';
    RangeValues priceRange = RangeValues(0, 5000);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.trenzyColors.graphite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.trenzyColors.mutedFg.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'FILTERS',
                      style: TextStyle(
                        color: context.trenzyColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Category',
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            [
                              'All',
                              'Dresses',
                              'Shoes',
                              'Tops',
                              'Bottoms',
                              'Accessories',
                            ].map((cat) {
                              final selected =
                                  selectedCategory == cat ||
                                  (cat == 'All' && selectedCategory == null);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GlassTag(
                                  text: cat,
                                  selected: selected,
                                  onTap: () => setSheetState(
                                    () => selectedCategory = cat == 'All'
                                        ? null
                                        : cat,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Price Range',
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    RangeSlider(
                      values: priceRange,
                      min: 0,
                      max: 10000,
                      divisions: 40,
                      activeColor: context.trenzyColors.primary,
                      inactiveColor: context.trenzyColors.background,
                      labels: RangeLabels(
                        '\u20B9${priceRange.start.toInt()}',
                        '\u20B9${priceRange.end.toInt()}',
                      ),
                      onChanged: (v) => setSheetState(() => priceRange = v),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sort By',
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            const [
                              ('relevance', 'RELEVANCE'),
                              ('price_asc', 'PRICE: LOW TO HIGH'),
                              ('price_desc', 'PRICE: HIGH TO LOW'),
                              ('rating', 'RATING'),
                            ].map((option) {
                              final s = option.$1;
                              return Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: GlassTag(
                                  text: option.$2,
                                  selected: sortBy == s,
                                  onTap: () => setSheetState(() => sortBy = s),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GlowButton(
                        label: 'Apply Filters',
                        onTap: () {
                          final params = <String, String>{};
                          if (selectedCategory != null &&
                              selectedCategory!.isNotEmpty) {
                            params['category'] = selectedCategory!;
                          }
                          if (sortBy.isNotEmpty) {
                            params['sort'] = sortBy;
                          }
                          if (priceRange.start > 0) {
                            params['min_price'] = priceRange.start
                                .toInt()
                                .toString();
                          }
                          if (priceRange.end < 10000) {
                            params['max_price'] = priceRange.end
                                .toInt()
                                .toString();
                          }
                          final qs = params.entries
                              .map(
                                (e) =>
                                    '${e.key}=${Uri.encodeComponent(e.value)}',
                              )
                              .join('&');
                          context.push(
                            '${AppRoutes.search}${qs.isNotEmpty ? '?$qs' : ''}',
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Section Widgets ──────────────────────────────────────────────────────────

class _CampaignBanner extends ConsumerWidget {
  const _CampaignBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(discoverCampaignProvider);

    return campaignAsync.when(
      loading: () => _CampaignBannerSkeleton(context: context),
      error: (e, _) => ErrorSection(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(discoverCampaignProvider),
        compact: true,
        padding: EdgeInsets.zero,
      ),
      data: (campaign) {
        if (campaign == null) return const SizedBox.shrink();
        final title = campaign['title'] as String? ?? 'Featured';
        final subtitle = campaign['subtitle'] as String? ?? '';
        final imageUrl = campaign['image_url'] as String?;
        final cta = campaign['cta'] as String? ?? 'Explore';

        return GlassContainer(
          radius: 24,
          padding: EdgeInsets.zero,
          clip: true,
          onTap: () {},
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.trenzyColors.primary.withValues(alpha: 0.25),
                  context.trenzyColors.graphite,
                ],
              ),
            ),
            child: Stack(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.trenzyColors.graphite.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.trenzyColors.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          'CAMPAIGN',
                          style: TextStyle(
                            color: context.trenzyColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 12),
                      TapScale(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: GlassGradients.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: context.trenzyColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            cta.toUpperCase(),
                            style: TextStyle(
                              color: context.trenzyColors.primaryFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
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
      },
    );
  }
}

class _CampaignBannerSkeleton extends StatelessWidget {
  const _CampaignBannerSkeleton({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return LoadingSkeletonShimmer(height: 180, radius: 24);
  }
}

class _SwipeDiscoveryPreview extends ConsumerWidget {
  const _SwipeDiscoveryPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(discoverSwipeProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Discover',
          subtitle: 'Swipe through curated picks',
          actionLabel: 'See All',
          onAction: () => context.push(AppRoutes.swipeDiscovery),
        ),
        SizedBox(height: 12),
        productsAsync.when(
          loading: () => _SwipeDiscoverySkeleton(),
          error: (e, _) => ErrorSection(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(discoverSwipeProductsProvider),
            compact: true,
            padding: EdgeInsets.zero,
          ),
          data: (products) {
            if (products.isEmpty) return const SizedBox.shrink();
            final preview = products.take(3).toList();

            return GestureDetector(
              onTap: () => context.push(AppRoutes.swipeDiscovery),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: List.generate(preview.length, (i) {
                    final offset = i * 16.0;
                    final scale = 1.0 - (i * 0.05);
                    final product = preview[i];

                    return Positioned(
                      right: offset,
                      top: offset,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 180,
                          height: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                product.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: product.imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 400,
                                        placeholder: (_, _) => Container(
                                          color: context.trenzyColors.graphite,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (_, _, _) => Container(
                                          color: context.trenzyColors.graphite,
                                          child: Icon(
                                            Icons.shopping_bag_rounded,
                                            size: 48,
                                            color: context.trenzyColors.mutedFg,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: context.trenzyColors.graphite,
                                        child: Icon(
                                          Icons.shopping_bag_rounded,
                                          size: 48,
                                          color: context.trenzyColors.mutedFg,
                                        ),
                                      ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  bottom: 14,
                                  right: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.effectiveBrand.toUpperCase(),
                                        style: TextStyle(
                                          color: context.trenzyColors.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        product.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        product.effectivePrice.toString(),
                                        style: TextStyle(
                                          color: context.trenzyColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SwipeDiscoverySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        children: List.generate(3, (i) {
          final offset = i * 16.0;
          return Positioned(
            right: offset,
            top: offset,
            child: LoadingSkeletonShimmer(height: 240, width: 180, radius: 20),
          );
        }),
      ),
    );
  }
}

class _PersonaSection extends ConsumerWidget {
  const _PersonaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personaAsync = ref.watch(personaProvider);

    return personaAsync.when(
      loading: () => _PersonaSkeleton(),
      error: (e, _) => ErrorSection(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(personaProvider),
        compact: true,
        padding: EdgeInsets.zero,
      ),
      data: (StylePersona? persona) {
        if (persona == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'Your Style Persona',
              subtitle: 'Based on your preferences',
              actionLabel: 'View Persona',
              onAction: () => context.push(AppRoutes.persona),
            ),
            SizedBox(height: 12),
            GlassContainer(
              radius: 24,
              padding: EdgeInsets.zero,
              clip: true,
              onTap: () => context.push(AppRoutes.persona),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.trenzyColors.primary.withValues(alpha: 0.25),
                      context.trenzyColors.graphite,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              context.trenzyColors.graphite.withValues(
                                alpha: 0.92,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.trenzyColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.trenzyColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Text(
                              'PERSONA',
                              style: TextStyle(
                                color: context.trenzyColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            persona.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            persona.keywords.join(', '),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonaSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeletonShimmer(height: 14, width: 80, radius: 7),
          SizedBox(height: 16),
          LoadingSkeletonShimmer(height: 22, width: 160, radius: 8),
          SizedBox(height: 10),
          LoadingSkeletonShimmer(height: 14, width: double.infinity, radius: 7),
          SizedBox(height: 10),
          LoadingSkeletonShimmer(height: 14, width: 200, radius: 7),
          SizedBox(height: 14),
          Row(
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LoadingSkeletonShimmer(
                  height: 28,
                  width: 64,
                  radius: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Categories',
          actionLabel: 'View All',
          onAction: () => context.push(AppRoutes.categories),
        ),
        SizedBox(height: 12),
        categoriesAsync.when(
          loading: () => _CategoryChipsSkeleton(),
          error: (e, _) => ErrorSection(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(categoriesProvider),
            compact: true,
            padding: EdgeInsets.zero,
          ),
          data: (categories) {
            if (categories.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return TapScale(
                    onTap: () {
                      context.push(
                        '${AppRoutes.search}?category=${Uri.encodeComponent(cat)}',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.graphite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.trenzyColors.glassBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcon(cat),
                            size: 16,
                            color: context.trenzyColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            cat,
                            style: TextStyle(
                              color: context.trenzyColors.foreground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  IconData categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('dress')) return Icons.checkroom_rounded;
    if (lower.contains('shoe') || lower.contains('foot')) {
      return Icons.directions_walk_rounded;
    }
    if (lower.contains('top') || lower.contains('shirt')) {
      return Icons.dry_cleaning_rounded;
    }
    if (lower.contains('bottom') || lower.contains('pant')) {
      return Icons.swap_vert_rounded;
    }
    if (lower.contains('accessor')) return Icons.watch_rounded;
    if (lower.contains('bag')) return Icons.shopping_bag_rounded;
    if (lower.contains('jewel')) return Icons.diamond_rounded;
    if (lower.contains('outer') || lower.contains('coat')) {
      return Icons.ac_unit_rounded;
    }
    return Icons.category_rounded;
  }
}

class _CategoryChipsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (_, _) =>
            LoadingSkeletonShimmer(height: 40, width: 100, radius: 20),
      ),
    );
  }
}

class _TrendingProducts extends ConsumerWidget {
  const _TrendingProducts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(
      trendingProductsProvider(TrendingParams(timeframe: 'daily', limit: 10)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Trending Now',
          subtitle: 'What everyone\'s watching',
          actionLabel: 'View All',
          onAction: () => context.push(AppRoutes.trends),
        ),
        SizedBox(height: 12),
        trendingAsync.when(
          loading: () => _TrendingSkeleton(),
          error: (e, _) => ErrorSection(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(
              trendingProductsProvider(
                TrendingParams(timeframe: 'daily', limit: 10),
              ),
            ),
            compact: true,
            padding: EdgeInsets.zero,
          ),
          data: (trends) {
            if (trends.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trends.length,
                separatorBuilder: (_, _) => SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final trend = trends[index];
                  final product = ProductModel.fromTrendModel(trend);

                  return SizedBox(
                    width: 160,
                    child: ProductCard(
                      product: product,
                      compact: true,
                      variant: ProductCardVariant.compact,
                      heroTagSuffix: '_trending_$index',
                      onTap: () {
                        context.push(
                          '${AppRoutes.productDetails}?productId=${product.id}',
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrendingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => SizedBox(width: 12),
        itemBuilder: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeletonShimmer(height: 140, width: 160, radius: 16),
            SizedBox(height: 10),
            LoadingSkeletonShimmer(height: 14, width: 120, radius: 7),
            SizedBox(height: 6),
            LoadingSkeletonShimmer(height: 14, width: 80, radius: 7),
          ],
        ),
      ),
    );
  }
}

class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(discoverRecommendedProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'For You',
          subtitle: 'AI-curated picks based on your style',
        ),
        SizedBox(height: 12),
        recommendedAsync.when(
          loading: () => _RecommendedSkeleton(),
          error: (e, _) => ErrorSection(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(discoverRecommendedProductsProvider),
            compact: true,
            padding: EdgeInsets.zero,
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptySection(
                title: 'No recommendations yet',
                subtitle:
                    'Complete your style profile to get personalized picks',
                icon: Icons.auto_awesome_rounded,
              );
            }

            return Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: items.length > 6 ? 6 : items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ProductCard(
                      product: item.product,
                      heroTagSuffix: '_rec_$index',
                      variant: ProductCardVariant.standard,
                      onTap: () {
                        context.push(
                          '${AppRoutes.productDetails}?productId=${item.product.id}',
                        );
                      },
                    );
                  },
                ),
                if (items.length > 6) ...[
                  SizedBox(height: 16),
                  TapScale(
                    onTap: () => context.push(AppRoutes.search),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.glass,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.trenzyColors.glassBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'See More Recommendations',
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecommendedSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeletonShimmer(
            height: 140,
            width: double.infinity,
            radius: 16,
          ),
          SizedBox(height: 8),
          LoadingSkeletonShimmer(height: 14, width: double.infinity, radius: 7),
          SizedBox(height: 6),
          LoadingSkeletonShimmer(height: 14, width: 80, radius: 7),
        ],
      ),
    );
  }
}
