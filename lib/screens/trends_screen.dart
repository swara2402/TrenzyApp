import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/trends_provider.dart';
import 'package:trenzy/models/trend_model.dart';
import 'package:trenzy/models/social_models.dart';
import 'package:trenzy/theme/glass_theme.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(
      trendingProductsProvider(TrendingParams(timeframe: 'daily', limit: 20)),
    );
    final predictionsAsync = ref.watch(
      trendPredictionsProvider(PredictionParams(limit: 10)),
    );

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            trendingProductsProvider(
              TrendingParams(timeframe: 'daily', limit: 20),
            ),
          );
          ref.invalidate(trendPredictionsProvider(PredictionParams(limit: 10)));
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
                      'TRENDS',
                      style: TextStyle(
                        fontFamily: GlassTypography.bodyFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    DisplayText('What\'s Hot Right Now', fontSize: 24),
                    SizedBox(height: 4),
                    Text(
                      'Trend analysis and forward-looking predictions',
                      style: GlassTypography.body(
                        color: context.trenzyColors.mutedFg,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Trending Products Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      'Trending Products',
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
            trendsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 4,
                    separatorBuilder: (_, _) => SizedBox(width: 12),
                    itemBuilder: (_, _) => LoadingSkeletonShimmer(
                      height: 220,
                      width: 150,
                      radius: 16,
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: context.trenzyColors.mutedFg,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Could not load trends',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                        SizedBox(height: 12),
                        GlowButton(
                          label: 'Retry',
                          width: 100,
                          height: 36,
                          onTap: () => ref.invalidate(
                            trendingProductsProvider(
                              TrendingParams(timeframe: 'daily', limit: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (trends) {
                if (trends.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: context.trenzyColors.primary.withValues(
                                alpha: 0.3,
                              ),
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No trends yet',
                              style: GlassTypography.body(
                                color: context.trenzyColors.mutedFg,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start exploring to generate trends',
                              style: GlassTypography.body(
                                color: context.trenzyColors.mutedFg,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: trends.length,
                      separatorBuilder: (_, _) => SizedBox(width: 12),
                      itemBuilder: (context, index) => _TrendProductCard(
                        trend: trends[index],
                        onTap: () => context.push(
                          AppRoutes.productDetailsFor(trends[index].productId),
                          extra: ProductDetailsRouteExtra(
                            productId: trends[index].productId,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Trend Predictions Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.trenzyColors.primary,
                            context.trenzyColors.emerald,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'AI Predictions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PREDICTION',
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 12)),
            predictionsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LoadingSkeletonShimmer(height: 100, radius: 16),
                      ),
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load predictions',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                        SizedBox(height: 8),
                        GlowButton(
                          label: 'Retry',
                          width: 100,
                          height: 36,
                          onTap: () => ref.invalidate(
                            trendPredictionsProvider(
                              PredictionParams(limit: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (predictions) {
                if (predictions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No predictions available yet',
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _PredictionCard(
                        prediction: predictions[index],
                        onTap: () => context.push(
                          AppRoutes.productDetailsFor(
                            predictions[index].productId,
                          ),
                          extra: ProductDetailsRouteExtra(
                            productId: predictions[index].productId,
                          ),
                        ),
                      ),
                    ),
                    childCount: predictions.length,
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

class _TrendProductCard extends StatelessWidget {
  final TrendModel trend;
  final VoidCallback onTap;

  const _TrendProductCard({required this.trend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        height: 220,
        child: GlassContainer(
          color: context.trenzyColors.graphite,
          radius: 16,
          child: Column(
            children: [
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child:
                          trend.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: trend.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[900],
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: context.trenzyColors.mutedFg,
                                    size: 24,
                                  ),
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
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: Icon(
                                Icons.image_outlined,
                                color: context.trenzyColors.mutedFg,
                                size: 24,
                              ),
                            ),
                    ),
                    // Trending score badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.emerald.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${trend.trendingScore.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trend.productName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.trenzyColors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ...[
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
                      Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            size: 10,
                            color: context.trenzyColors.fg40,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '${trend.viewCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.trenzyColors.fg40,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.touch_app,
                            size: 10,
                            color: context.trenzyColors.fg40,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '${trend.clickCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.trenzyColors.fg40,
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

class _PredictionCard extends StatelessWidget {
  final PredictionModel prediction;
  final VoidCallback? onTap;

  const _PredictionCard({required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (prediction.confidence * 100).toStringAsFixed(0);
    final trendPercent = prediction.predictedTrendScore.toStringAsFixed(0);

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        color: context.trenzyColors.graphite,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child:
                      prediction.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: prediction.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: Icon(
                              Icons.auto_awesome,
                              color: context.trenzyColors.primary,
                              size: 20,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[900],
                            child: Icon(
                              Icons.auto_awesome,
                              color: context.trenzyColors.primary,
                              size: 20,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: Icon(
                            Icons.auto_awesome,
                            color: context.trenzyColors.primary,
                            size: 20,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.productName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ...[
                    SizedBox(height: 2),
                    Text(
                      prediction.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                  ],
                    SizedBox(height: 6),
                    Text(
                      prediction.reasoning,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.trenzyColors.fg60,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Score column
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.trenzyColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$trendPercent%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.trenzyColors.primary,
                          ),
                        ),
                        Text(
                          'TREND',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: context.trenzyColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '$confidencePercent% conf',
                    style: TextStyle(
                      fontSize: 9,
                      color: context.trenzyColors.fg40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
