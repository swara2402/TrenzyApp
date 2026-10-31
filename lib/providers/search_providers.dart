import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

final searchSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) async {
      if (query.trim().length < 2) return [];
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <String>[];

      final api = ref.watch(apiServiceProvider);
      try {
        final res = await api.getSuggestions(query.trim());
        return res.cast<String>();
      } catch (_) {
        return [];
      }
    });

final unifiedSearchProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, query) async {
      if (query.trim().length < 2) return {};
      final api = ref.watch(apiServiceProvider);
      try {
        return await api.unifiedSearch(query.trim());
      } catch (_) {
        return {};
      }
    });

final searchQueryProvider = StateProvider<String>((ref) => '');

final debouncedSearchQueryProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(searchQueryProvider);
});


/// Loads catalog products by their actual category instead of searching for
/// the category word as free text (which can hide valid items such as bottoms).
class CategorySearchParams {
  const CategorySearchParams({
    required this.category,
    this.sort,
    this.minPrice,
    this.maxPrice,
  });

  final String category;
  final String? sort;
  final double? minPrice;
  final double? maxPrice;

  @override
  bool operator ==(Object other) =>
      other is CategorySearchParams &&
      category == other.category &&
      sort == other.sort &&
      minPrice == other.minPrice &&
      maxPrice == other.maxPrice;

  @override
  int get hashCode => Object.hash(category, sort, minPrice, maxPrice);
}

final categorySearchProductsProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, CategorySearchParams>((ref, filters) async {
  final uid = ref.watch(
    auth_p.authProvider.select((a) => a.valueOrNull?.id),
  );
  if (uid == null) return const <ProductModel>[];
  final api = ref.watch(apiServiceProvider);
  final raw = await api.searchProducts(
    query: '',
    category: filters.category,
    minPrice: filters.minPrice?.round(),
    maxPrice: filters.maxPrice?.round(),
    sort: filters.sort == 'rating' ? 'rating_desc' : filters.sort,
  );
  return raw
      .whereType<Map>()
      .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});
