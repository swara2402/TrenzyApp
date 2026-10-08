import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class WardrobeApi {
  WardrobeApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getWardrobe({
    String? category,
    String? color,
    String? season,
    String? brand,
    bool favoriteOnly = false,
    String? search,
    int offset = 0,
    int limit = 50,
  }) async {
    final qp = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty) qp['category'] = category;
    if (color != null && color.isNotEmpty) qp['color'] = color;
    if (season != null && season.isNotEmpty) qp['season'] = season;
    if (brand != null && brand.isNotEmpty) qp['brand'] = brand;
    if (favoriteOnly) qp['favorite_only'] = 'true';
    if (search != null && search.isNotEmpty) qp['search'] = search;

    final data = await _client.get('/wardrobe', queryParams: qp);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getWardrobeRecommendations({int limit = 5}) async {
    final data = await _client.get('/wardrobe/recommendations', queryParams: {
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> addWardrobeItem({
    required String name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (imageUrl != null) body['imageUrl'] = imageUrl;
    if (category != null) body['category'] = category;
    if (color != null) body['color'] = color;
    if (season != null) body['season'] = season;
    if (brand != null) body['brand'] = brand;

    await _client.post('/wardrobe', body: body);
  }

  Future<void> updateWardrobeItem(
    int itemId, {
    String? name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
    bool? isFavorite,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (imageUrl != null) body['imageUrl'] = imageUrl;
    if (category != null) body['category'] = category;
    if (color != null) body['color'] = color;
    if (season != null) body['season'] = season;
    if (brand != null) body['brand'] = brand;
    if (isFavorite != null) body['is_favorite'] = isFavorite;

    await _client.patch('/wardrobe/$itemId', body: body);
  }

  Future<void> deleteWardrobeItem(int itemId) async {
    await _client.delete('/wardrobe/$itemId');
  }

  Future<String> uploadImage(XFile imageFile) async {
    final data = await _client.uploadMultipart('/uploads/image', imageFile);
    if (data is Map<String, dynamic>) {
      final imageUrl = data['image_url']?.toString() ?? data['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    }
    throw StateError('Image upload response did not contain an image URL.');
  }

  Future<Map<String, dynamic>> getOutfits() async {
    final data = await _client.get('/wardrobe/outfits');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createOutfit({
    required String name,
    required List<int> wardrobeItemIds,
    String? occasion,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'wardrobe_item_ids': wardrobeItemIds,
    };
    if (occasion != null) body['occasion'] = occasion;

    final data = await _client.post('/wardrobe/outfits', body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> updateOutfit(
    int outfitId, {
    String? name,
    String? occasion,
    List<int>? wardrobeItemIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (occasion != null) body['occasion'] = occasion;
    if (wardrobeItemIds != null) body['wardrobe_item_ids'] = wardrobeItemIds;

    await _client.patch('/wardrobe/outfits/$outfitId', body: body);
  }

  Future<void> deleteOutfit(int outfitId) async {
    await _client.delete('/wardrobe/outfits/$outfitId');
  }
}
