part of 'home_screen.dart';

class _JustDroppedSection extends ConsumerWidget {
  const _JustDroppedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final prefs = ref.watch(userPreferencesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.trenzyColors.emerald,
                      context.trenzyColors.primary.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 10),
              Text(
                prefs.preferredCategories.isNotEmpty
                    ? 'New in ${prefs.preferredCategories.first}'
                    : 'Just Dropped',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.trenzyColors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          feedAsync.when(
            loading: () => SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => SizedBox(width: 12),
                itemBuilder: (_, _) =>
                    LoadingSkeletonShimmer(height: 190, width: 130, radius: 16),
              ),
            ),
            error: (_, _) => ErrorSection(
              title: 'Couldn\u2019t load new drops',
              message: 'Fresh drops are unavailable right now.',
              compact: true,
              onRetry: () => ref.invalidate(feedProvider),
            ),
            data: (feed) {
              final justDropped = feed.sections
                  .where((s) => s.id == 'just_dropped')
                  .expand((s) => s.products)
                  .toList();
              if (justDropped.isEmpty) {
                return EmptySection(
                  title: 'No new drops yet',
                  subtitle: 'Check back soon for latest arrivals.',
                );
              }
              return SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: justDropped.length,
                  separatorBuilder: (_, _) => SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final p = justDropped[index];
                    return GestureDetector(
                      onTap: () => context.push(
                        AppRoutes.productDetailsFor((p['id'] ?? '').toString()),
                        extra: ProductDetailsRouteExtra(
                          productId: (p['id'] ?? '').toString(),
                        ),
                      ),
                      child: SizedBox(
                        width: 130,
                        child: GlassContainer(
                          color: context.trenzyColors.graphite,
                          radius: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      ApiService.resolveImageUrl(
                                        p['image_url'],
                                      ) ??
                                      'https://placehold.co/400x400/1a1a2e/666.png?text=No+Image',
                                  height: 120,
                                  width: 130,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 260,
                                  placeholder: (_, _) => Container(
                                    height: 120,
                                    color: Colors.grey[900],
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: context.trenzyColors.mutedFg,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    height: 120,
                                    color: Colors.grey[900],
                                    child: Icon(
                                      Icons.broken_image,
                                      color: context.trenzyColors.mutedFg,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (p['brand'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: context.trenzyColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      p['name'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.trenzyColors.foreground,
                                      ),
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
              );
            },
          ),
        ],
      ),
    );
  }
}
