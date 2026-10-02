import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;
import 'wishlist_provider.dart';

/// Products list provider with pagination support.
///
/// Backend endpoints are protected with Firebase bearer token.
/// This provider blocks HTTP calls until Firebase auth is ready.
///
/// Flow:
///  - auth.isLoading  → return [] (loading skeleton shown by UI)
///  - user == null    → return [] (user not signed in, quiet empty state)
///  - user != null    → fetch from backend and return real products
///
/// When the user logs in/out, auth_provider.dart calls ref.invalidate(productsProvider)
/// which clears the cache and triggers a fresh fetch.
final productsProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, ({String? category})>((ref, filters) async {
      final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
      if (uid == null) return const <ProductModel>[];

      final api = ref.watch(apiServiceProvider);
      try {
        final result = await api.getProducts(
          category: filters.category,
        );
        final products = result['products'] as List<dynamic>? ?? [];

        return products
            .map(
              (e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {
        return const <ProductModel>[];
      }
    });

final subcategoriesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, categoryName) async {
      final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
      if (uid == null) return const <String>[];

      final api = ref.watch(apiServiceProvider);
      try {
        return await api.getSubcategories(categoryName);
      } catch (_) {
        return const <String>[];
      }
    });

final brandsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return {};

  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getBrands();
  } catch (_) {
    return {};
  }
});

final categoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <String>[];

  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getCategories();
  } catch (_) {
    return const <String>[];
  }
});

final productDetailsProvider = FutureProvider.autoDispose
    .family<ProductModel, String>((ref, productId) async {
      final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));

      if (uid == null) {
        return ProductModel(id: productId, name: 'Product unavailable');
      }

      final api = ref.watch(apiServiceProvider);
      try {
        final product = await api.getProduct(productId);
        return ProductModel.fromJson(Map<String, dynamic>.from(product));
      } catch (_) {
        return ProductModel(id: productId, name: 'Product unavailable');
      }
    });

final productSearchProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, ProductSearchParams>((ref, params) async {
      if (params.query.trim().isEmpty &&
          params.category == null &&
          params.subcategory == null &&
          params.gender == null &&
          params.color == null &&
          params.season == null &&
          params.brand == null &&
          params.minPrice == null &&
          params.maxPrice == null) {
        return [];
      }

      final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));

      if (uid == null) return const <ProductModel>[];

      final api = ref.watch(apiServiceProvider);
      final products = await api.searchProducts(
        query: params.query,
        category: params.category,
        subcategory: params.subcategory,
        gender: params.gender,
        color: params.color,
        season: params.season,
        brand: params.brand,
        minPrice: params.minPrice?.toInt(),
        maxPrice: params.maxPrice?.toInt(),
        sort: params.sort,
      );

      return products
          .map(
            (e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

final wishlistProductsProvider = FutureProvider.autoDispose<List<ProductModel>>(
  (ref) async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));

    if (uid == null) return const <ProductModel>[];

    try {
      final wishlistState = await ref.watch(wishlistProvider.future);
      final productIds = wishlistState.productIds;

      if (productIds.isEmpty) return [];

      final api = ref.watch(apiServiceProvider);
      final result = await api.getBatchProducts(productIds.toList());
      final products = result['products'] as List<dynamic>? ?? [];
      return products
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const <ProductModel>[];
    }
  },
);