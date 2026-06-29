import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;
import 'wishlist_provider.dart';

/// Products list provider.
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
    .family<List<ProductModel>, String?>((ref, category) async {
      final auth = ref.watch(auth_p.authProvider);

      // Auth is still resolving — return empty list so UI shows loading skeleton.
      if (auth.isLoading) return const <ProductModel>[];

      // Not signed in — return empty list quietly.
      final user = auth.value;
      if (user == null) return const <ProductModel>[];

      final api = ref.watch(apiServiceProvider);
      final products = await api.getProducts(category: category);
      return products
          .map(
            (e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

final categoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final auth = ref.watch(auth_p.authProvider);
  if (auth.isLoading) return const <String>[];
  final user = auth.value;
  if (user == null) return const <String>[];

  final api = ref.watch(apiServiceProvider);
  return api.getCategories();
});

final productDetailsProvider = FutureProvider.autoDispose
    .family<ProductModel, String>((ref, productId) async {
      final auth = ref.watch(auth_p.authProvider);
      final user = auth.value;

      if (user == null) {
        return ProductModel(id: productId, name: 'Product unavailable');
      }

      final api = ref.watch(apiServiceProvider);
      final product = await api.getProduct(productId);
      return ProductModel.fromJson(Map<String, dynamic>.from(product));
    });

final productSearchProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, ProductSearchParams>((ref, params) async {
      if (params.query.trim().isEmpty &&
          params.category == null &&
          params.minPrice == null &&
          params.maxPrice == null) {
        return [];
      }

      final auth = ref.watch(auth_p.authProvider);
      final user = auth.value;

      if (user == null) return const <ProductModel>[];

      final api = ref.watch(apiServiceProvider);
      final products = await api.searchProducts(
        query: params.query,
        category: params.category,
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
    final auth = ref.watch(auth_p.authProvider);
    final user = auth.value;

    if (user == null) return const <ProductModel>[];

    final wishlistState = await ref.watch(wishlistProvider.future);
    final productIds = wishlistState.productIds;

    if (productIds.isEmpty) return [];

    final api = ref.watch(apiServiceProvider);
    final products = <ProductModel>[];
    for (final productId in productIds) {
      try {
        final product = await api.getProduct(productId);
        products.add(ProductModel.fromJson(Map<String, dynamic>.from(product)));
      } catch (_) {
        // Skip unavailable products silently.
      }
    }
    return products;
  },
);
