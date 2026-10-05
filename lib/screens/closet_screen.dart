import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/wardrobe_provider.dart';
import '../providers/home_providers.dart';
import '../models/wardrobe_model.dart';
import '../theme/glass_theme.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../widgets/section_states.dart';

class ClosetScreen extends ConsumerWidget {
  const ClosetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeAsync = ref.watch(wardrobeProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.foreground),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'My Closet',
          style: TextStyle(color: context.trenzyColors.primary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.trenzyColors.mutedFg),
            onPressed: () {
              ref.invalidate(wardrobeProvider);
              ref.invalidate(wardrobeRecommendationsProvider);
              ref.invalidate(aiOutfitMatchesProvider);
            },
          ),
        ],
      ),
      body: wardrobeAsync.when(
        loading: () => Center(
          child: LoadingSkeletonShimmer(height: 400, radius: 16),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 72, color: context.trenzyColors.mutedFg),
                SizedBox(height: 20),
                Text(
                  'Could not load wardrobe',
                  style: TextStyle(
                    color: context.trenzyColors.foreground.withValues(alpha: 0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.invalidate(wardrobeProvider);
                    ref.invalidate(wardrobeRecommendationsProvider);
                    ref.invalidate(aiOutfitMatchesProvider);
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          final items = state.items;
          if (items.isEmpty) {
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
                        color: context.trenzyColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.checkroom_rounded,
                        size: 40,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                    SizedBox(height: 20),
                    DisplayText(
                      'Your wardrobe is empty',
                      fontSize: 20,
                      weight: FontWeight.w700,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your wardrobe powers smarter recommendations.\nAdd your first piece to get started.',
                      textAlign: TextAlign.center,
                      style: GlassTypography.body(
                        color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),
                    GlowButton(
                      label: 'Add Item to Closet',
                      onTap: () => context.push(AppRoutes.addItem),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(wardrobeProvider);
              ref.invalidate(wardrobeRecommendationsProvider);
              ref.invalidate(aiOutfitMatchesProvider);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
                  if (state.hasMore && !state.isLoadingMore) {
                    ref.read(wardrobeProvider.notifier).loadMore();
                  }
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _AiOutfitMatchBanner(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _WardrobeCard(item: items[index]),
                        childCount: items.length,
                      ),
                    ),
                  ),
                  if (state.hasMore || state.isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: state.isLoadingMore
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.trenzyColors.primary,
                                  ),
                                )
                              : TextButton(
                                  onPressed: () {
                                    ref.read(wardrobeProvider.notifier).loadMore();
                                  },
                                  child: Text('Load More', style: TextStyle(color: context.trenzyColors.primary)),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.trenzyColors.primary,
        foregroundColor: context.trenzyColors.primaryFg,
        onPressed: () => context.push(AppRoutes.addItem),
        child: Icon(Icons.add),
      ),
    );
  }
}

class _AiOutfitMatchBanner extends ConsumerWidget {
  const _AiOutfitMatchBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(aiOutfitMatchesProvider);
    return outfitsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: context.trenzyColors.glass,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: ErrorSection(
          title: 'Couldn\u2019t load outfit matches',
          message: 'We couldn\u2019t fetch your AI outfit matches right now.',
          compact: true,
          padding: EdgeInsets.zero,
          onRetry: () {
            ref.invalidate(wardrobeRecommendationsProvider);
            ref.invalidate(aiOutfitMatchesProvider);
          },
        ),
      ),
      data: (outfits) {
        if (outfits.isEmpty) return SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.outfitBuilder),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.trenzyColors.primary.withValues(alpha: 0.15),
                    context.trenzyColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: context.trenzyColors.primary,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AI found ${outfits.length} outfit ${outfits.length == 1 ? 'idea' : 'ideas'}',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.trenzyColors.foreground,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          (outfits.first.title?.isNotEmpty == true) ? outfits.first.title! : 'Matches your wardrobe perfectly',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 12,
                            color: context.trenzyColors.mutedFg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.trenzyColors.mutedFg,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WardrobeCard extends StatelessWidget {
  const _WardrobeCard({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final name = item.name;
    final category = item.category;
    final isFavorite = item.isFavorite;

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.editClothing,
          extra: EditClothingRouteExtra(wardrobeItem: item),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.trenzyColors.graphite,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: context.trenzyColors.graphite,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: context.trenzyColors.graphite,
                            child: Icon(Icons.broken_image,
                                color: context.trenzyColors.mutedFg),
                          ),
                        )
                      : Container(
                          color: context.trenzyColors.graphite,
                          child: Icon(Icons.checkroom_rounded,
                              color: context.trenzyColors.mutedFg),
                        ),
                  if (isFavorite == true)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.favorite,
                          size: 16, color: context.trenzyColors.primary),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.trenzyColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: TextStyle(
                        color: context.trenzyColors.mutedFg.withValues(alpha: 0.6),
                        fontSize: 11,
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