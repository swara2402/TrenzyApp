import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../models/user_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;
import 'user_preferences_provider.dart';

final discoverCampaignProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return null;

      final api = ref.watch(apiServiceProvider);
      return api.getFeaturedCampaign();
    });

final discoverTrendingCreatorsProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <UserModel>[];

      final api = ref.watch(apiServiceProvider);
      final res = await api.getRecommendedPeople(limit: 10);
      final people = res['people'] as List<dynamic>? ?? [];
      return people
          .map(
            (json) =>
                UserModel.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();
    });

final discoverRecommendedUsersProvider = discoverTrendingCreatorsProvider;

final discoverTrendingOutfitsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <ProductModel>[];

      final api = ref.watch(apiServiceProvider);
      final res = await api.getRecommendedOutfits(limit: 6);
      final outfits = res['outfits'] as List<dynamic>? ?? [];
      return outfits
          .map((item) {
            final map = item as Map;
            final product = map['product'] as Map<String, dynamic>?;
            if (product == null) return null;
            return ProductModel.fromJson(product);
          })
          .whereType<ProductModel>()
          .toList();
    });

class RecommendedProduct {
  final ProductModel product;
  final String reason;

  const RecommendedProduct({required this.product, required this.reason});
}

final discoverRecommendedProductsProvider =
    FutureProvider.autoDispose<List<RecommendedProduct>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <RecommendedProduct>[];

      // Watch preferences so recommendations refetch when preferences change
      ref.watch(userPreferencesProvider);

      final api = ref.watch(apiServiceProvider);
      final res = await api.getRecommendations();
      final items = res['items'] as List<dynamic>? ?? [];
      return items
          .map((item) {
            final map = item as Map;
            final data = map['data'] as Map<String, dynamic>?;
            if (data == null) return null;
            final reason = map['reason']?.toString() ?? '';
            final productData = Map<String, dynamic>.from(data)
              ..['reason'] = reason;

            return RecommendedProduct(
              product: ProductModel.fromJson(productData),
              reason: reason,
            );
          })
          .whereType<RecommendedProduct>()
          .toList();
    });

final personalizedFeedProvider = discoverRecommendedProductsProvider;

final personaStylesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <String>[];

  final api = ref.watch(apiServiceProvider);
  return api.getPersonaStyles();
});

final personaColorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <Map<String, dynamic>>[];

      final api = ref.watch(apiServiceProvider);
      return api.getPersonaColors();
    });

final discoverSwipeProductsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <ProductModel>[];

      ref.watch(userPreferencesProvider);

      final api = ref.watch(apiServiceProvider);
      final res = await api.discoverSwipe(limit: 20);
      final products = res['products'] as List<dynamic>? ?? [];
      return products.map((item) {
        final map = item as Map;
        return ProductModel.fromJson(Map<String, dynamic>.from(map));
      }).toList();
    });
