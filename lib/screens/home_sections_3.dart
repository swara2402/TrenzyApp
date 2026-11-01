part of 'home_screen.dart';

class _AiPicksSection extends ConsumerWidget {
  const _AiPicksSection();

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.trenzyColors.primary),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: GlassTypography.bodyFont,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.trenzyColors.foreground,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picksAsync = ref.watch(todaysAiPicksProvider);
    final catalogAsync = ref.watch(productsProvider((category: null)));
    return picksAsync.when(
      loading: () {
        final catalog = catalogAsync.valueOrNull ?? const <ProductModel>[];
        if (catalog.isNotEmpty) {
          return _homeCatalogFallback(
            context,
            catalog,
            title: 'Fresh picks for you',
            heroTag: '_for_you_loading_fallback',
            startIndex: 0,
            onRetry: () => ref.invalidate(todaysAiPicksProvider),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, 'For You', Icons.auto_awesome_rounded),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(width: 130, child: ProductCardSkeleton()),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      error: (error, _) => _homeCatalogFallback(
        context,
        catalogAsync.valueOrNull ?? const <ProductModel>[],
        title: 'Fresh picks to explore',
        heroTag: '_home_error_fallback',
        startIndex: 0,
        onRetry: () => ref.invalidate(todaysAiPicksProvider),
      ),
      data: (picks) {
        if (picks.isEmpty) {
          final catalog = catalogAsync.valueOrNull ?? const <ProductModel>[];
          if (catalog.isEmpty) {
            return EmptySection(
              title: 'We\u2019re still learning your style',
              subtitle:
                  'Explore a few items and we\u2019ll start recommending pieces just for you.',
              actionLabel: 'Explore',
              onAction: () => context.go(AppRoutes.discover),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, 'Fresh picks to explore', Icons.auto_awesome_rounded),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: catalog.take(8).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 150,
                      child: ProductCard(
                        product: catalog[index],
                        compact: true,
                        variant: ProductCardVariant.compact,
                        heroTagSuffix: '_home_fallback_$index',
                        onTap: () => context.push(
                          AppRoutes.productDetailsFor(catalog[index].id),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, 'For You', Icons.auto_awesome_rounded),
              SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: picks.map((rec) {
                    final product = rec.product;
                    final reasonText = rec.reason.isNotEmpty
                        ? rec.reason
                        : (generateReasons(product).isNotEmpty
                              ? generateReasons(product).first.label
                              : '');
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 260,
                              child: ProductCard(
                                product: product,
                                variant: ProductCardVariant.compact,
                                onTap: () => context.push(
                                  AppRoutes.productDetailsFor(product.id),
                                  extra: ProductDetailsRouteExtra(
                                    productId: product.id,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6),
                            if (reasonText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.trenzyColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 10,
                                      color: context.trenzyColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        reasonText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: context.trenzyColors.primary,
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
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InspiredByWardrobeSlot extends ConsumerWidget {
  const _InspiredByWardrobeSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(aiOutfitMatchesProvider);

    return outfitsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LoadingSkeletonShimmer(
          height: 72,
          radius: GlassRadius.card,
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: ErrorSection(
          title: 'Couldn\u2019t load wardrobe matches',
          message: friendlyError(error),
          compact: true,
          padding: EdgeInsets.zero,
          onRetry: () => ref.invalidate(aiOutfitMatchesProvider),
        ),
      ),
      data: (outfits) {
        if (outfits.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(height: 24),
            StaggeredEntry(
              index: 6,
              child: _InspiredByWardrobeCard(outfits: outfits),
            ),
          ],
        );
      },
    );
  }
}

class _InspiredByWardrobeCard extends StatelessWidget {
  const _InspiredByWardrobeCard({required this.outfits});

  final List<OutfitIdea> outfits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.outfitBuilder),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.trenzyColors.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.trenzyColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  color: context.trenzyColors.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspired by Your Wardrobe',
                      style: TextStyle(
                        fontFamily: GlassTypography.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${outfits.length} outfits match your saved items',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.trenzyColors.mutedFg,
                      ),
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
  }
}
