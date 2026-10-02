import 'api_client.dart';

class WishlistApi {
  WishlistApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getWishlist() async {
    final data = await _client.get('/wishlist');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> setWishlist(List<String> productIds) async {
    await _client.post('/wishlist', body: {'productIds': productIds});
  }

  Future<void> addWishlistItem(String productId) async {
    await _client.post('/wishlist/add', body: {'productId': productId});
  }

  Future<void> removeWishlistItem(String productId) async {
    await _client.delete('/wishlist/$productId');
  }
}
