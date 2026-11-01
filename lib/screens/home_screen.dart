import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/home_providers.dart';
import '../providers/products_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/trends_provider.dart';
import '../providers/blend_provider.dart';
import '../providers/wardrobe_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/glass_theme.dart';
import '../providers/user_preferences_provider.dart';
import '../models/blend_model.dart';
import '../models/product_model.dart';

import '../services/api_service.dart';

import '../models/trend_model.dart';
import '../models/wardrobe_model.dart';
import '../widgets/product_card.dart';
import '../widgets/section_states.dart';
import '../utils/ai_explanations.dart';

part 'home_sections_1.dart';
part 'home_sections_2.dart';
part 'home_sections_3.dart';
part 'home_sections_4.dart';
part 'home_sections_6.dart';
part 'home_sections_7.dart';

Widget _homeCatalogFallback(
  BuildContext context,
  List<ProductModel> catalog, {
  required String title,
  required String heroTag,
  required int startIndex,
  required VoidCallback onRetry,
}) {
  final items = catalog.skip(startIndex).take(8).toList();
  if (items.isEmpty) {
    return ErrorSection(
      title: title,
      message: 'Catalog picks are unavailable right now.',
      compact: true,
      onRetry: onRetry,
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          style: TextStyle(
            color: context.trenzyColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) => SizedBox(
            width: 150,
            child: ProductCard(
              product: items[index],
              compact: true,
              variant: ProductCardVariant.compact,
              heroTagSuffix: '${heroTag}_$index',
              onTap: () => context.push(
                AppRoutes.productDetailsFor(items[index].id),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(
            trendingProductsProvider(
              TrendingParams(timeframe: 'daily', limit: 10),
            ),
          );
          ref.invalidate(todaysAiPicksProvider);
          ref.invalidate(userBlendGroupsProvider);
          ref.invalidate(wardrobeProvider);
          final prefs = ref.read(userPreferencesProvider);
          if (prefs.preferredCategories.isNotEmpty) {
            ref.invalidate(
              trendingProductsProvider(
                TrendingParams(
                  categories: prefs.preferredCategories.join(','),
                  timeframe: 'daily',
                  limit: 10,
                ),
              ),
            );
          }
        },
        color: context.trenzyColors.primary,
        backgroundColor: context.trenzyColors.graphite,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            StaggeredEntry(index: 0, child: _WelcomeHeader()),
            _AiPersonaCard(),
            _ContinueBlendSlot(),
            StaggeredEntry(index: 1, child: _AiPicksSection()),
            SizedBox(height: 24),
            StaggeredEntry(index: 2, child: _TrendingSection()),
            SizedBox(height: 24),
            StaggeredEntry(index: 3, child: _JustDroppedSection()),
            _InspiredByWardrobeSlot(),
            SizedBox(height: 16),
            StaggeredEntry(index: 4, child: _SeeMoreSection()),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
