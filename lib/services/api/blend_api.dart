import 'api_client.dart';

class BlendApi {
  BlendApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> createBlend({
    required String name,
    String? description,
    String? theme,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (description != null) body['description'] = description;
    if (theme != null) body['theme'] = theme;

    final data = await _client.post('/blends', body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }


  Future<void> inviteToBlend({
    required String blendId,
    required String inviterId,
    required String inviteeId,
  }) async {
    await _client.post('/blends/$blendId/invitations', body: {
      'invitee_id': inviteeId,
    });
  }

  Future<void> respondToBlendInvitation({
    required String invitationId,
    required String status,
  }) async {
    await _client.put('/blends/invitations/$invitationId', body: {
      'status': status,
    });
  }

  Future<Map<String, dynamic>> joinBlend({required String groupId}) async {
    final data = await _client.post('/blends/join', body: {'groupId': groupId});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> leaveBlend(String groupId) async {
    await _client.delete('/blends/$groupId/leave');
  }

  Future<Map<String, dynamic>> getBlendGroup(String groupId) async {
    final data = await _client.get('/blends/$groupId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBlendResults(String groupId) async {
    final data = await _client.get('/blends/$groupId/results');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> recordBlendSwipe({
    required String groupId,
    required String productId,
    required String swipeType,
  }) async {
    await _client.post('/blends/swipe', body: {
      'groupId': groupId,
      'productId': productId,
      'swipeType': swipeType,
    });
  }

  Future<void> undoBlendSwipe({
    required String groupId,
    required String productId,
  }) async {
    await _client.delete('/blends/$groupId/swipes/$productId');
  }

  Future<List<dynamic>> getUserBlendGroups() async {
    final data = await _client.get('/blends');
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['blends'] is List) {
      return data['blends'] as List<dynamic>;
    }
    return [];
  }

  Future<void> disbandBlend(String groupId) async {
    await _client.delete('/blends/$groupId');
  }

  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) async {
    final data = await _client.post('/blends/$groupId/invitations', body: {
      'expiresInSeconds': expiresInSeconds,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acceptInvitation({required String token}) async {
    final data = await _client.post('/blends/invitations/accept', body: {'token': token});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBlendDashboard(String blendId) async {
    final data = await _client.get('/blends/$blendId/dashboard');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<List<dynamic>> getSharedWishlist(
    String blendId, {
    String? sort,
    String? category,
    String? search,
  }) async {
    final qp = <String, String>{};
    if (sort != null) qp['sort'] = sort;
    if (category != null) qp['category'] = category;
    if (search != null) qp['search'] = search;

    final data = await _client.get(
      '/blends/$blendId/wishlist',
      queryParams: qp.isNotEmpty ? qp : null,
    );
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> addToSharedWishlist(
    String blendId, {
    required String productId,
    String productName = '',
    double? productPrice,
    String? productImage,
    String? productBrand,
    String? productCategory,
    String? productUrl,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'productName': productName,
    };
    if (productPrice != null) body['productPrice'] = productPrice;
    if (productImage != null) body['productImage'] = productImage;
    if (productBrand != null) body['productBrand'] = productBrand;
    if (productCategory != null) body['productCategory'] = productCategory;
    if (productUrl != null) body['productUrl'] = productUrl;
    if (notes != null) body['notes'] = notes;

    final data = await _client.post(
      '/blends/$blendId/wishlist',
      body: body,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateWishlistItem(
    String blendId,
    int itemId, {
    String? notes,
    bool? isFavorite,
    String? purchaseLink,
  }) async {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (isFavorite != null) body['isFavorite'] = isFavorite;
    if (purchaseLink != null) body['purchaseLink'] = purchaseLink;

    final data = await _client.patch(
      '/blends/$blendId/wishlist/$itemId',
      body: body,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> removeFromSharedWishlist(String blendId, int itemId) async {
    await _client.delete('/blends/$blendId/wishlist/$itemId');
  }

  Future<List<dynamic>> getMoodboard(String blendId, {String? itemType}) async {
    final qp = itemType != null ? {'itemType': itemType} : null;
    final data = await _client.get(
      '/blends/$blendId/moodboard',
      queryParams: qp,
    );
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> addToMoodboard(
    String blendId, {
    required String itemType,
    Map<String, dynamic>? content,
    String? imageUrl,
    String? caption,
  }) async {
    final body = <String, dynamic>{'itemType': itemType};
    if (content != null) body['content'] = content;
    if (imageUrl != null) body['imageUrl'] = imageUrl;
    if (caption != null) body['caption'] = caption;

    final data = await _client.post(
      '/blends/$blendId/moodboard',
      body: body,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> removeFromMoodboard(String blendId, int itemId) async {
    await _client.delete('/blends/$blendId/moodboard/$itemId');
  }

  Future<List<dynamic>> getBlendInsights(String blendId, {bool refresh = false}) async {
    final data = await _client.get(
      '/blends/$blendId/insights',
      queryParams: refresh ? {'refresh': 'true'} : null,
    );
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['insights'] is List) {
      return data['insights'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> refreshBlendInsights(String blendId) async {
    final data = await _client.post('/blends/$blendId/insights/refresh');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> updateBlendSettings(
    String blendId, {
    String? name,
    String? description,
    String? coverImage,
    bool? isPrivate,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (coverImage != null) body['coverImage'] = coverImage;
    if (isPrivate != null) body['isPrivate'] = isPrivate;

    await _client.patch('/blends/$blendId/settings', body: body);
  }

  Future<Map<String, dynamic>> getBlendSettings(String blendId) async {
    final data = await _client.get('/blends/$blendId/settings');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBlendActivity(
    String blendId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client.get(
      '/blends/$blendId/activity',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
