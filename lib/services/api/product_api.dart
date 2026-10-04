import 'api_client.dart';

class ProductApi {
  ProductApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getProducts({
    String? category,
    String? subcategory,
    String? gender,
    String? color,
    String? season,
    String? brand,
    int offset = 0,
    int limit = 24,
  }) async {
    final qp = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty) qp['category'] = category;
    if (subcategory != null && subcategory.isNotEmpty) qp['subcategory'] = subcategory;
    if (gender != null && gender.isNotEmpty) qp['gender'] = gender;
    if (color != null && color.isNotEmpty) qp['color'] = color;
    if (season != null && season.isNotEmpty) qp['season'] = season;
    if (brand != null && brand.isNotEmpty) qp['brand'] = brand;

    final cacheKey = 'products_${qp.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _client.get(
      '/products',
      queryParams: qp,
      cacheTtl: const Duration(minutes: 5),
      cacheKey: cacheKey,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    final data = await _client.get('/products/$productId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<List<dynamic>> searchProducts({
    required String query,
    String? category,
    String? subcategory,
    String? gender,
    String? color,
    String? season,
    String? brand,
    int? minPrice,
    int? maxPrice,
    String? sort,
  }) async {
    final qp = <String, String>{'q': query};
    if (category != null && category.isNotEmpty) qp['category'] = category;
    if (subcategory != null && subcategory.isNotEmpty) qp['subcategory'] = subcategory;
    if (gender != null && gender.isNotEmpty) qp['gender'] = gender;
    if (color != null && color.isNotEmpty) qp['color'] = color;
    if (season != null && season.isNotEmpty) qp['season'] = season;
    if (brand != null && brand.isNotEmpty) qp['brand'] = brand;
    if (minPrice != null) qp['min_price'] = minPrice.toString();
    if (maxPrice != null) qp['max_price'] = maxPrice.toString();
    if (sort != null && sort.isNotEmpty) qp['sort'] = sort;

    final data = await _client.get('/products/search', queryParams: qp);
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['products'] is List) {
      return data['products'] as List<dynamic>;
    }
    return [];
  }

  Future<List<String>> getCategories() async {
    final data = await _client.get(
      '/categories',
      cacheTtl: const Duration(seconds: 30),
      cacheKey: 'categories',
    );
    if (data is List) {
      return data.map((e) => e is Map ? e['name']?.toString() ?? '' : e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (data is Map<String, dynamic> && data['categories'] is List) {
      return (data['categories'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<String>> getSubcategories(String categoryName) async {
    final data = await _client.get('/categories/$categoryName/subcategories');
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getBrands({String? search}) async {
    final qp = search != null && search.isNotEmpty ? {'search': search} : null;
    final data = await _client.get('/brands', queryParams: qp);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> archiveProduct(String productId) async {
    await _client.delete('/products/$productId');
    _client.invalidateCache('products_');
  }

  Future<Map<String, dynamic>> getBatchProducts(List<String> ids) async {
    final data = await _client.get('/products/batch', queryParams: {
      'ids': ids.join(','),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> unifiedSearch(String query, {int limit = 10}) async {
    final data = await _client.get('/search', queryParams: {
      'q': query,
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<List<dynamic>> getSuggestions(String query) async {
    final data = await _client.get('/suggestions', queryParams: {'q': query});
    final List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map<String, dynamic> && data['suggestions'] is List) {
      raw = data['suggestions'] as List<dynamic>;
    } else {
      raw = const [];
    }
    return raw
        .map(
          (e) => e is Map
              ? (e['name'] ?? e['title'] ?? e['text'] ?? '').toString()
              : e.toString(),
        )
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
