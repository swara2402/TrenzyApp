part of 'home_screen.dart';

class _JustDroppedSection extends ConsumerWidget {
  const _JustDroppedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final catalogAsync = ref.watch(productsProvider((category: null)));
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
            loading: () {
              final catalog = catalogAsync.valueOrNull ?? const <ProductModel>[];
              if (catalog.isNotEmpty) {
                return _homeCatalogFallback(
                  context,
                  catalog,
                  title: 'Fresh from the catalog',
                  heroTag: '_just_dropped_loading_fallback',
                  startIndex: 16,
                  onRetry: () => ref.invalidate(feedProvider),
                );
              }
              return SizedBox(
                height: 270,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, _) => SizedBox(width: 12),
                  itemBuilder: (_, _) => LoadingSkeletonShimmer(
                    height: 190,
                    width: 130,
                    radius: 16,
                  ),
                ),
              );
            },
            error: (_, _) => _homeCatalogFallback(
              context,
              catalogAsync.valueOrNull ?? const <ProductModel>[],
              title: 'Fresh from the catalog',
              heroTag: '_just_dropped_error_fallback',
              startIndex: 16,
              onRetry: () => ref.invalidate(feedProvider),
            ),
            data: (feed) {
              final justDropped = feed.sections
                  .where((s) => s.id == 'just_dropped')
                  .expand((s) => s.products)
                  .toList();
              if (justDropped.isEmpty) {
                final catalog = catalogAsync.valueOrNull ?? const <ProductModel>[];
                if (catalog.isEmpty) {
                  return EmptySection(
                    title: 'No new drops yet',
                    subtitle: 'Explore the latest catalog picks instead.',
                    actionLabel: 'Explore',
                    onAction: () => context.go(AppRoutes.discover),
                  );
                }
                return SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: catalog.skip(16).take(8).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 150,
                      child: ProductCard(
                        product: catalog[index + 16],
                        compact: true,
                        variant: ProductCardVariant.compact,
                        heroTagSuffix: '_just_dropped_fallback_$index',
                        onTap: () => context.push(
                          AppRoutes.productDetailsFor(catalog[index + 16].id),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 270,
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
                        width: 155,
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
                                  height: 170,
                                  width: 155,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 310,
                                  placeholder: (_, _) => Container(
                                    height: 170,
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
                                        fontSize: 13,
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
