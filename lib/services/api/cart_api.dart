import 'api_client.dart';

class CartApi {
  CartApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getCart() async {
    final data = await _client.get('/cart');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addCartItem({
    required String productId,
    int quantity = 1,
  }) async {
    final data = await _client.post('/cart/items', body: {
      'product_id': productId,
      'quantity': quantity,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateCartItem({
    required String productId,
    required int quantity,
  }) async {
    final data = await _client.put('/cart/items/$productId', body: {
      'quantity': quantity,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> removeCartItem(String productId) async {
    await _client.delete('/cart/items/$productId');
  }

  Future<void> clearCart() async {
    await _client.delete('/cart');
  }
}
