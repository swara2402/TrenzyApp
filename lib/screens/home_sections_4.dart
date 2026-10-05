part of 'home_screen.dart';

class _TrendingSection extends ConsumerStatefulWidget {
  const _TrendingSection();

  @override
  ConsumerState<_TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends ConsumerState<_TrendingSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);
    final userCategories = prefs.preferredCategories;
    final categoriesParam = userCategories.isNotEmpty ? userCategories.join(',') : null;

    final trendsAsync = ref.watch(
      trendingProductsProvider(TrendingParams(
        categories: categoriesParam,
        timeframe: 'daily',
        limit: 10,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.trenzyColors.crimson, context.trenzyColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 10),
              Text(
                '\uD83D\uDD25 Trending Now',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.trenzyColors.foreground,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            prefs.preferredCategories.isNotEmpty
                ? "Trending in ${prefs.preferredCategories.first}"
                : "Based on what's popular in your network",
            style: TextStyle(
              fontFamily: GlassTypography.bodyFont,
              fontSize: 12,
              color: context.trenzyColors.mutedFg,
            ),
          ),
        ),
        SizedBox(height: 12),
        trendsAsync.when(
          loading: () => SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, _) => SizedBox(width: 12),
              itemBuilder: (_, _) => LoadingSkeletonShimmer(
                height: 190,
                width: 130,
                radius: 16,
              ),
            ),
          ),
          error: (err, _) => ErrorSection(
            title: 'Couldn\u2019t load trending',
            message: friendlyError(err),
            compact: true,
            onRetry: () => ref.invalidate(trendingProductsProvider(TrendingParams(
              categories: categoriesParam,
              timeframe: 'daily',
              limit: 10,
            ))),
          ),
          data: (trends) {
            if (trends.isEmpty) {
              return EmptySection(
                title: 'Nothing trending yet',
                subtitle: 'Check back soon for the latest styles.',
              );
            }
            return SizedBox(
              height: 190,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trends.length,
                separatorBuilder: (_, _) => SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _TrendingProductCard(
                    trend: trends[index],
                    scrollController: _scrollController,
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

class _TrendingProductCard extends StatefulWidget {
  final TrendModel trend;
  final ScrollController scrollController;

  const _TrendingProductCard({
    required this.trend,
    required this.scrollController,
  });

  @override
  _TrendingProductCardState createState() => _TrendingProductCardState();
}

class _TrendingProductCardState extends State<_TrendingProductCard>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_updateOpacity);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOpacity());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateOpacity);
    super.dispose();
  }

  void _updateOpacity() {
    if (!mounted) return;
    final RenderBox? renderBox =
        _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardLeft = position.dx;
    final cardRight = cardLeft + renderBox.size.width;

    double newOpacity;
    if (cardRight < 100 || cardLeft > screenWidth - 100) {
      newOpacity = 0.2;
    } else {
      newOpacity = 1.0;
    }

    if (newOpacity != _opacity) {
      setState(() {
        _opacity = newOpacity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 190,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: Duration(milliseconds: 200),
        child: GlassContainer(
          key: _cardKey,
          color: context.trenzyColors.graphite,
          radius: 16,
          child: Column(
            children: [
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: ApiService.resolveImageUrl(widget.trend.imageUrl) ?? 'https://placehold.co/400x600/1a1a2e/666.png?text=No+Image',
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 260,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: Icon(Icons.image_outlined,
                                color: context.trenzyColors.mutedFg, size: 24),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.broken_image,
                            size: 24,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                    // Gradient scrim at bottom of image
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trend.productName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.trenzyColors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.trend.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.trenzyColors.mutedFg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(Icons.trending_up,
                              size: 10, color: context.trenzyColors.emerald),
                          SizedBox(width: 4),
                          Text(
                            '${widget.trend.trendingScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: context.trenzyColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

