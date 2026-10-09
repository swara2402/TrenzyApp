import 'dart:async';
import 'package:trenzy/models/friend.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service_base.dart';

class MockApiService implements ApiServiceBase {
  Future<void> _delay(Duration d) async => await Future.delayed(d);

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    await _delay(const Duration(milliseconds: 500));
    return {
      'token': 'mock_token_123',
      'user': {
        'id': 'firebase_12345',
        'name': 'Demo User',
        'email': email,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    await _delay(const Duration(milliseconds: 500));
    return {
      'token': 'mock_token_123',
      'user': {
        'id': 'firebase_12345',
        'name': name,
        'email': email,
      },
    };
  }

  @override
  Future<Map<String, dynamic>?> googleLogin() async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'user': {
        'id': 'firebase_98765',
        'name': 'Google Demo',
        'email': 'google@example.com',
        'token': 'google_mock_token',
      },
      'sessionId': 'session_xyz',
    };
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    await _delay(const Duration(milliseconds: 200));
    return {
      'id': 'firebase_12345',
      'name': 'Demo User',
      'email': 'demo@example.com',
      'token': 'mock_token_123',
      'avatarUrl': 'https://placehold.co/150x150/1a1a2e/666.png?text=D',
    };
  }

  @override
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
    await _delay(const Duration(milliseconds: 400));
    return {'products': [], 'total': 0, 'offset': offset, 'limit': limit};
  }

  @override
  Future<Map<String, dynamic>> getProduct(String productId) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'id': productId,
      'name': 'Premium Peach Sneakers',
      'brand': 'PEACHLUXE',
      'article_type': 'Footwear',
      'usage': 'casual',
      'price': 1499.99,
      'rating': 4.7,
      'image_url': 'https://placehold.co/600x800/1a1a2e/666.png?text=Product',
      'category': 'Footwear',
      'tags': const ['limited', 'exclusive'],
      'affiliate_links': ['https://example.com/affiliates/peach1'],
    };
  }

  @override
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
    await _delay(const Duration(milliseconds: 350));
    return [];
  }

  @override
  Future<List<String>> getCategories() async {
    await _delay(const Duration(milliseconds: 200));
    return ['Upper', 'Bottom', 'Footwear'];
  }

  @override
  Future<List<String>> getSubcategories(String categoryName) async {
    await _delay(const Duration(milliseconds: 200));
    if (categoryName == 'Upper') {
      return ['T-Shirt', 'Shirt', 'Polo', 'Sweater', 'Hoodie'];
    } else if (categoryName == 'Bottom') {
      return ['Jeans', 'Shorts', 'Joggers', 'Leggings'];
    } else if (categoryName == 'Footwear') {
      return ['Sneakers', 'Boots', 'Sandals', 'Loafers'];
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getBrands({String? search}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'brands': ['PEACHLUXE', 'NIKE', 'ADIDAS', 'LEVI\'S']};
  }

  @override
  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'name': name};
  }

  @override
  Future<Map<String, dynamic>> getWishlist() async {
    await _delay(const Duration(milliseconds: 150));
    return {
      'userId': 'firebase_12345',
      'productIds': ['p_0', 'p_5'],
    };
  }

  @override
  Future<void> setWishlist(List<String> productIds) async {
    await _delay(const Duration(milliseconds: 250));
  }

  // In-memory mock cart for local/dev
  static final List<Map<String, dynamic>> _mockCartItems = [];
  static int _mockCartIdSeq = 1;

  @override
  Future<Map<String, dynamic>> getCart() async {
    await _delay(const Duration(milliseconds: 150));
    double total = 0;
    final items = <Map<String, dynamic>>[];
    for (final ci in _mockCartItems) {
      final price = (ci['price'] as num?)?.toDouble() ?? 0;
      final qty = (ci['quantity'] as int?) ?? 1;
      total += price * qty;
      items.add({
        'id': ci['id'],
        'quantity': qty,
        'product': {
          'id': ci['product_id'],
          'name': ci['title'] ?? 'Product',
          'price': price,
          'images': ci['images'] ?? <String>[],
        },
      });
    }
    return {
      'cart': _mockCartItems.isEmpty
          ? null
          : {'id': 1, 'created_at': DateTime.now().toIso8601String()},
      'items': items,
      'total': double.parse(total.toStringAsFixed(2)),
    };
  }

  @override
  Future<Map<String, dynamic>> addCartItem({
    required String productId,
    int quantity = 1,
  }) async {
    await _delay(const Duration(milliseconds: 200));
    for (final ci in _mockCartItems) {
      if (ci['product_id'] == productId) {
        ci['quantity'] = ((ci['quantity'] as int?) ?? 1) + quantity;
        return {
          'id': ci['id'],
          'product_id': productId,
          'title': ci['title'],
          'price': ci['price'],
          'quantity': ci['quantity'],
        };
      }
    }
    final id = _mockCartIdSeq++;
    final row = {
      'id': id,
      'product_id': productId,
      'title': 'Product $productId',
      'price': 999.0,
      'quantity': quantity,
      'images': <String>[],
    };
    _mockCartItems.add(row);
    return {
      'id': id,
      'product_id': productId,
      'title': row['title'],
      'price': row['price'],
      'quantity': quantity,
    };
  }

  @override
  Future<Map<String, dynamic>> updateCartItem({
    required String productId,
    required int quantity,
  }) async {
    await _delay(const Duration(milliseconds: 150));
    for (final ci in _mockCartItems) {
      if (ci['product_id'] == productId) {
        ci['quantity'] = quantity;
        return {
          'id': ci['id'],
          'product_id': productId,
          'title': ci['title'],
          'price': ci['price'],
          'quantity': quantity,
        };
      }
    }
    throw Exception('Cart item not found');
  }

  @override
  Future<void> removeCartItem(String productId) async {
    await _delay(const Duration(milliseconds: 100));
    _mockCartItems.removeWhere((ci) => ci['product_id'] == productId);
  }

  @override
  Future<void> clearCart() async {
    await _delay(const Duration(milliseconds: 100));
    _mockCartItems.clear();
  }

  @override
  Future<List<dynamic>> getSuggestions(String query) async {
    await _delay(const Duration(milliseconds: 100));
    return [];
  }

  @override
  Future<String> getReasoning({
    required String query,
    required String optionTitle,
    required String optionPrice,
    required int aiScore,
    required int socialApproval,
  }) async {
    await _delay(const Duration(milliseconds: 400));
    return 'This is a great choice because...';
  }

  @override
  Future<void> saveDecision({
    required String query,
    required List<Map<String, dynamic>> selectedOptions,
    required String recommendedOptionId,
    required int socialApproval,
    required String reasoning,
  }) async {
    await _delay(const Duration(milliseconds: 300));
  }

  @override
  Future<List<dynamic>> getDecisions() async {
    await _delay(const Duration(milliseconds: 200));
    return [];
  }

  @override
  Future<Map<String, dynamic>> createBlend({
    required String name,
    String? description,
    String? theme,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'id': 'blend_123',
      'name': name,
      'description': description,
      'theme': theme,
    };
  }

  @override
  Future<void> inviteToBlend({
    required String blendId,
    required String inviterId,
    required String inviteeId,
  }) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> reportIssue({
    required String category,
    required String description,
  }) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> resetPassword(String email) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> addWishlistItem(String productId) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> removeWishlistItem(String productId) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    await _delay(const Duration(milliseconds: 200));
    return {'user': {'id': userId, 'name': 'Test User', 'avatarUrl': '', 'bio': ''}};
  }

  @override
  Future<void> reportUser({
    required String targetFirebaseUid,
    required String reason,
    String? details,
  }) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> followUser(String targetFirebaseUid) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> unfollowUser(String targetFirebaseUid) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<bool> getFollowStatus(String targetFirebaseUid) async {
    await _delay(const Duration(milliseconds: 100));
    return false;
  }

  @override
  Future<Map<String, dynamic>> getFollowers() async {
    await _delay(const Duration(milliseconds: 200));
    return {'followers': []};
  }

  @override
  Future<Map<String, dynamic>> getFollowing() async {
    await _delay(const Duration(milliseconds: 200));
    return {'following': []};
  }

  @override
  Future<Map<String, dynamic>> unifiedSearch(String query, {int limit = 10}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'products': [], 'users': [], 'blends': []};
  }

  @override
  Future<void> registerPushToken(String token, {String platform = 'fcm'}) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> discoverSwipe({int limit = 20}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'products': []};
  }

  @override
  Future<void> recordDiscoverySwipe({required String productId, required String swipeType}) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<List<String>> getPersonaStyles() async {
    await _delay(const Duration(milliseconds: 200));
    return ['Casual', 'Formal', 'Sporty', 'Bohemian', 'Minimalist', 'Streetwear', 'Classic', 'Vintage'];
  }

  @override
  Future<List<String>> getPersonaProductTypes() async {
    await _delay(const Duration(milliseconds: 200));
    return ['T-Shirts', 'Shirts', 'Jeans', 'Dresses', 'Sneakers', 'Jackets'];
  }

  @override
  Future<List<Map<String, dynamic>>> getPersonaColors() async {
    await _delay(const Duration(milliseconds: 200));
    return [
      {'name': 'Black', 'hex': '#000000'},
      {'name': 'White', 'hex': '#FFFFFF'},
      {'name': 'Blue', 'hex': '#2196F3'},
      {'name': 'Red', 'hex': '#F44336'},
    ];
  }

  @override
  Future<void> disbandBlend(String groupId) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> updateOutfit(int outfitId, {
    String? name,
    String? occasion,
    List<int>? wardrobeItemIds,
  }) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> joinBlend({required String groupId}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'id': groupId, 'name': 'Mock Blend', 'inviteCode': groupId};
  }

  @override
  Future<void> leaveBlend(String groupId) async {
    await _delay(const Duration(milliseconds: 150));
  }

  @override
  Future<Map<String, dynamic>> getBlendGroup(String groupId) async {
    await _delay(const Duration(milliseconds: 250));
    return {};
  }

  @override
  Future<Map<String, dynamic>> getBlendResults(String groupId) async {
    await _delay(const Duration(milliseconds: 300));
    return {};
  }

  @override
  Future<void> recordBlendSwipe({
    required String groupId,
    required String productId,
    required String swipeType,
  }) async {
    await _delay(const Duration(milliseconds: 150));
  }

  @override
  Future<void> undoBlendSwipe({
    required String groupId,
    required String productId,
  }) async {
    await _delay(const Duration(milliseconds: 150));
  }

  @override
  Future<List<dynamic>> getUserBlendGroups() async {
    await _delay(const Duration(milliseconds: 200));
    return [];
  }

  @override
  Future<Map<String, dynamic>> getGroupMessages({
    required String groupId,
    int limit = 50,
  }) async {
    await _delay(const Duration(milliseconds: 200));
    return {'messages': []};
  }

  @override
  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  }) async {
    await _delay(const Duration(milliseconds: 200));
  }

  // ---------- AI ----------
  @override
  Future<Map<String, dynamic>> getStyleDna() async {
    await _delay(const Duration(milliseconds: 150));
    return {'style_scores': {'casual': 0.8}, 'color_scores': {'neutrals': 0.75}, 'fit_scores': {'relaxed': 0.7}, 'brand_scores': {}, 'category_scores': {'tops': 0.8}, 'occasion_scores': {'college': 0.85}, 'material_scores': {}, 'price_sensitivity': 0.5, 'confidence': 0.6, 'interaction_count': 12, 'explanation': 'Mock Style DNA'};
  }
  @override
  Future<Map<String, dynamic>> refreshStyleDna() async { await _delay(const Duration(milliseconds: 100)); return {'message': 'Style DNA refreshed', 'confidence': 0.6}; }
  @override
  Future<Map<String, dynamic>> getAiModelHealth() async { await _delay(const Duration(milliseconds: 100)); return {'status': 'degraded', 'models': {}}; }
  @override
  Future<Map<String, dynamic>> getAiRecommendations({int limit = 20}) async { await _delay(const Duration(milliseconds: 100)); return {'products': [], 'explanations': [], 'source': 'mock', 'limit': limit}; }
  @override
  Future<Map<String, dynamic>> generateAiOutfits({required String prompt, int numOptions = 3, Map<String, dynamic>? context}) async { await _delay(const Duration(milliseconds: 100)); return {'success': true, 'outfits': [], 'message': 'No mock outfits available.'}; }
  @override
  Future<Map<String, dynamic>> aiStylistChat({required String message, int? conversationId}) async { await _delay(const Duration(milliseconds: 100)); return {'conversation_id': conversationId ?? 1, 'message': 'Mock stylist response', 'mentioned_products': []}; }
  @override
  Future<Map<String, dynamic>> aiStylistOutfit(String prompt) async { await _delay(const Duration(milliseconds: 100)); return {'success': true, 'outfits': []}; }
  @override
  Future<Map<String, dynamic>> aiVisualSearch(XFile image, {int limit = 20}) async { await _delay(const Duration(milliseconds: 100)); return {'products': [], 'similarities': []}; }

  @override
  Future<Map<String, dynamic>> getNotifications() async {
    await _delay(const Duration(milliseconds: 200));
    return {'notifications': []};
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    await _delay(const Duration(milliseconds: 100));
    return {'unreadCount': 0};
  }

  @override
  Future<List<Friend>> getFriends() async {
    await _delay(const Duration(milliseconds: 200));
    return [
      Friend(id: '1', firebaseUid: 'alice', name: 'Alice', avatarUrl: 'https://placehold.co/150x150/1a1a2e/666.png?text=A'),
      Friend(id: '2', firebaseUid: 'bob', name: 'Bob', avatarUrl: 'https://placehold.co/150x150/1a1a2e/666.png?text=B'),
    ];
  }

  @override
  Future<void> sendFriendRequest({required String toFirebaseUid}) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<List<dynamic>> getFriendRequests({String box = 'incoming'}) async {
    await _delay(const Duration(milliseconds: 200));
    return [];
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> rejectFriendRequest(int requestId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> removeFriend(int friendId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<List<FriendSuggestion>> getFriendSuggestions() async {
    await _delay(const Duration(milliseconds: 200));
    return const [];
  }

  @override
  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'token': 'invite_abc_123',
      'expiresAt': DateTime.now()
          .add(Duration(seconds: expiresInSeconds))
          .millisecondsSinceEpoch,
    };
  }

  @override
  Future<Map<String, dynamic>> acceptInvitation({required String token}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'success': true, 'groupName': 'Mock Group'};
  }

  @override
  Future<List<dynamic>> getTrendingProducts({
    String? category,
    String? categories,
    String timeframe = 'daily',
    int limit = 20,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<List<dynamic>> getTrendPredictions({
    String? category,
    int limit = 10,
  }) async {
    await _delay(const Duration(milliseconds: 250));
    return [];
  }

  @override
  Future<void> trackProductView(String productId) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<String?> trackAffiliateClick(String productId) async {
    await _delay(const Duration(milliseconds: 150));
    return null;
  }

  @override
  Future<Map<String, dynamic>> aggregateTrends({
    String timeframe = 'daily',
  }) async {
    await _delay(const Duration(milliseconds: 400));
    return {};
  }

  @override
  Future<Map<String, dynamic>?> getFeaturedCampaign() async {
    await _delay(const Duration(milliseconds: 300));
    return null;
  }

  @override
  Future<Map<String, dynamic>> getRecommendedPeople({int limit = 10}) async {
    await _delay(const Duration(milliseconds: 300));
    return {'people': []};
  }

  @override
  Future<Map<String, dynamic>> getRecommendedOutfits({int limit = 6}) async {
    await _delay(const Duration(milliseconds: 300));
    return {'outfits': []};
  }

  @override
  Future<Map<String, dynamic>> getRecommendedProducts({
    int limit = 12,
    String? category,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {'products': []};
  }

  @override
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
    await _delay(const Duration(milliseconds: 300));
    return {'wardrobe': [], 'pagination': {'offset': offset, 'limit': limit, 'total': 0, 'hasMore': false}};
  }

  @override
  Future<Map<String, dynamic>> getWardrobeRecommendations({int limit = 5}) async {
    await _delay(const Duration(milliseconds: 200));
    return {
      'summary': {'itemCount': 0, 'byRole': {}, 'byCategory': {}, 'topColors': []},
      'gaps': [],
      'productSuggestions': [],
      'outfitIdeas': [],
    };
  }

  @override
  Future<void> addWardrobeItem({
    required String name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
  }) async {
    await _delay(const Duration(milliseconds: 300));
  }

  @override
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
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> deleteWardrobeItem(int itemId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<String> uploadImage(XFile imageFile) async {
    await _delay(const Duration(milliseconds: 1000)); // Simulate network delay
    return 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/600/400';
  }

  @override
  Future<Map<String, dynamic>> getOutfits() async {
    await _delay(const Duration(milliseconds: 300));
    return {'outfits': []};
  }

  @override
  Future<Map<String, dynamic>> createOutfit({
    required String name,
    required List<int> wardrobeItemIds,
    String? occasion,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {'id': 1, 'name': name};
  }

  @override
  Future<void> deleteOutfit(int outfitId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<Map<String, dynamic>?> getPersona() async {
    await _delay(const Duration(milliseconds: 300));
    return null;
  }

  @override
  Future<Map<String, dynamic>> generatePersona(
      {Map<String, dynamic>? preferences}) async {
    await _delay(const Duration(milliseconds: 500));
    return {};
  }

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    await _delay(const Duration(milliseconds: 200));
    return {};
  }

  @override
  Future<void> savePreferences({
    List<String>? preferredCategories,
    List<String>? preferredBrands,
    List<String>? preferredColors,
    List<String>? preferredSeasons,
    List<String>? preferredStyles,
    List<String>? preferredAesthetics,
    List<String>? preferredOccasions,
    int? budgetMax,
    List<String>? discoverPreferences,
    List<String>? productInterests,
    List<String>? shoppingPriorities,
    int? onboardingStep,
  }) async {
    await _delay(const Duration(milliseconds: 300));
  }

  @override
  Future<Map<String, dynamic>> createPost({
    required String content,
    String? attachment,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {'id': 1, 'content': content};
  }

  @override
  Future<Map<String, dynamic>> getUserPosts({
    String? userId,
    int offset = 0,
    int limit = 20,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {'posts': []};
  }

  @override
  Future<void> deletePost(int postId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> likePost(int postId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<void> unlikePost(int postId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<Map<String, dynamic>> commentOnPost(int postId, String content) async {
    await _delay(const Duration(milliseconds: 300));
    return {'id': 1, 'content': content};
  }

  @override
  Future<Map<String, dynamic>> getComments(int postId) async {
    await _delay(const Duration(milliseconds: 200));
    return {'comments': []};
  }

  @override
  Future<Map<String, dynamic>> getFeed({int offset = 0, int limit = 20}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'sections': [], 'pagination': {'offset': offset, 'limit': limit}};
  }

  @override
  Future<Map<String, dynamic>> getDirectMessages({
    required String friendFirebaseUid,
    int limit = 50,
    int? beforeId,
  }) async {
    await _delay(const Duration(milliseconds: 120));
    return {'conversationId': 'mock-chat', 'messages': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> sendDirectMessage({
    required String toFirebaseUid,
    required String message,
  }) async {
    await _delay(const Duration(milliseconds: 120));
    return {
      'message': {
        'id': DateTime.now().millisecondsSinceEpoch,
        'senderFirebaseUid': 'firebase_12345',
        'recipientFirebaseUid': toFirebaseUid,
        'message': message,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getActivity(
      {int limit = 20, int offset = 0}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'activity': []};
  }

  @override
  Future<void> createActivity({
    required String kind,
    required String description,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadataJson,
  }) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<void> respondToBlendInvitation({
    required String invitationId,
    required String status,
  }) async {
    await _delay(const Duration(milliseconds: 100));
  }

  @override
  Future<Map<String, dynamic>> verifyAge(DateTime dateOfBirth) async {
    await _delay(const Duration(milliseconds: 150));
    return {'ageVerified': true, 'isMinor': false};
  }

  @override
  Future<void> deleteAccount() async {
    await _delay(const Duration(milliseconds: 500));
  }

  @override
  Future<Map<String, dynamic>> getBatchProducts(List<String> ids) async {
    await _delay(const Duration(milliseconds: 300));
    return {'products': []};
  }

  @override
  Future<void> archiveProduct(String productId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<Map<String, dynamic>> getRecommendations() async {
    await _delay(const Duration(milliseconds: 300));
    return {'items': []};
  }

  @override
  Future<Map<String, dynamic>> createPaymentOrder({
    required int amountPaise,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'razorpay_order_id': 'mock_order_123',
      'id': 'mock_order_123',
      'amount_paise': amountPaise,
      'currency': 'INR',
      'key_id': 'mock_key',
      'simulation': true,
      'checkout_url': 'https://example.invalid/api/payments/checkout',
    };
  }

  @override
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'status': 'completed',
      'order_id': 'ORD_MOCK0001',
      'message': 'Payment verified and order created',
    };
  }

  @override
  Future<Map<String, dynamic>> getPaymentOrderStatus({
    required String razorpayOrderId,
  }) async {
    await _delay(const Duration(milliseconds: 200));
    return {
      'status': 'completed',
      'order_id': 'ORD_MOCK0001',
      'amount_paise': 129900,
      'currency': 'INR',
    };
  }

  // ── Mock: Blend Dashboard ─────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getBlendDashboard(String blendId) async {
    await _delay(const Duration(milliseconds: 400));
    return {
      'id': blendId,
      'name': 'Mock Blend',
      'description': 'A mock blend for testing',
      'inviteCode': blendId,
      'memberCount': 2,
      'members': [
        {'userId': 'user1', 'userName': 'Alice', 'swipeCount': 15},
        {'userId': 'user2', 'userName': 'Bob', 'swipeCount': 12},
      ],
      'fashionScore': 72,
      'compatibilityLevel': 'High',
      'sharedBrands': ['Nike', 'Adidas', 'Zara'],
      'sharedCategories': ['Footwear', 'Tops'],
      'sharedColours': ['Black', 'White', 'Neutral'],
      'sharedStyles': ['Casual', 'Sporty'],
      'wardrobeOverlap': 3,
      'totalSwipes': 27,
      'totalWishlistItems': 5,
      'totalMoodboardItems': 3,
      'styleDNA': {
        'colors': [
          {'name': 'Black', 'confidence': 45.0},
          {'name': 'White', 'confidence': 30.0},
          {'name': 'Neutral', 'confidence': 25.0},
        ],
        'brands': [
          {'name': 'Nike', 'confidence': 40.0},
          {'name': 'Adidas', 'confidence': 35.0},
          {'name': 'Zara', 'confidence': 25.0},
        ],
        'fits': [],
        'categories': [
          {'name': 'Footwear', 'confidence': 50.0},
          {'name': 'Tops', 'confidence': 30.0},
          {'name': 'Accessories', 'confidence': 20.0},
        ],
        'aesthetics': [
          {'name': 'streetwear', 'confidence': 55.0},
          {'name': 'minimal', 'confidence': 45.0},
        ],
        'occasions': [
          {'name': 'Casual', 'confidence': 60.0},
          {'name': 'Sporty', 'confidence': 40.0},
        ],
      },
      'wishlistItems': [
        {
          'id': 1, 'productId': 'p1', 'productName': 'Classic Sneakers',
          'productPrice': 129.99, 'productImage': null, 'productBrand': 'Nike',
          'productCategory': 'Footwear', 'addedByUid': 'user1', 'addedByName': 'Alice',
          'isFavorite': true, 'notes': 'Love these!',
        },
      ],
      'moodboardItems': [],
      'insights': [
        {
          'id': 1, 'insightType': 'color_preference', 'title': 'You prefer black tones',
          'description': '45% of your liked products feature black colors.',
          'confidence': 0.75, 'category': 'colors',
        },
      ],
      'recentActivity': [
        {'id': 1, 'kind': 'swipe', 'description': 'Alice liked Classic Sneakers', 'userId': 'user1'},
      ],
    };
  }

  @override
  Future<List<dynamic>> getSharedWishlist(String blendId, {String? sort, String? category, String? search}) async {
    await _delay(const Duration(milliseconds: 300));
    return [
      {'id': 1, 'productId': 'p1', 'productName': 'Classic Sneakers', 'productPrice': 129.99, 'productBrand': 'Nike', 'productCategory': 'Footwear', 'addedByUid': 'user1', 'addedByName': 'Alice', 'isFavorite': true},
      {'id': 2, 'productId': 'p2', 'productName': 'Leather Jacket', 'productPrice': 299.99, 'productBrand': 'Zara', 'productCategory': 'Outerwear', 'addedByUid': 'user2', 'addedByName': 'Bob', 'isFavorite': false},
    ];
  }

  @override
  Future<Map<String, dynamic>> addToSharedWishlist(String blendId, {required String productId, String productName = '', double? productPrice, String? productImage, String? productBrand, String? productCategory, String? productUrl, String? notes}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'id': 99, 'status': 'added', 'productId': productId, 'productName': productName};
  }

  @override
  Future<Map<String, dynamic>> updateWishlistItem(String blendId, int itemId, {String? notes, bool? isFavorite, String? purchaseLink}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'status': 'updated', 'id': itemId};
  }

  @override
  Future<void> removeFromSharedWishlist(String blendId, int itemId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<List<dynamic>> getMoodboard(String blendId, {String? itemType}) async {
    await _delay(const Duration(milliseconds: 300));
    return [
      {'id': 1, 'itemType': 'product', 'imageUrl': null, 'caption': 'Love this vibe', 'addedByUid': 'user1', 'addedByName': 'Alice'},
      {'id': 2, 'itemType': 'color_palette', 'content': {'colors': ['#000', '#FFF', '#888']}, 'caption': 'Minimal palette', 'addedByUid': 'user2', 'addedByName': 'Bob'},
    ];
  }

  @override
  Future<Map<String, dynamic>> addToMoodboard(String blendId, {required String itemType, Map<String, dynamic>? content, String? imageUrl, String? caption}) async {
    await _delay(const Duration(milliseconds: 200));
    return {'id': 99, 'status': 'added'};
  }

  @override
  Future<void> removeFromMoodboard(String blendId, int itemId) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<List<dynamic>> getBlendInsights(String blendId, {bool refresh = false}) async {
    await _delay(const Duration(milliseconds: 300));
    return [
      {'id': 1, 'insightType': 'color_preference', 'title': 'You both prefer neutral colors', 'description': 'Most of your liked products use neutral tones.', 'confidence': 0.82, 'category': 'colors'},
      {'id': 2, 'insightType': 'brand_affinity', 'title': 'Nike is a group favorite', 'description': '40% of liked items are from Nike.', 'confidence': 0.75, 'category': 'brands'},
    ];
  }

  @override
  Future<Map<String, dynamic>> refreshBlendInsights(String blendId) async {
    await _delay(const Duration(milliseconds: 500));
    return {'status': 'refreshed', 'count': 5};
  }

  @override
  Future<void> updateBlendSettings(String blendId, {String? name, String? description, String? coverImage, bool? isPrivate}) async {
    await _delay(const Duration(milliseconds: 200));
  }

  @override
  Future<Map<String, dynamic>> getBlendSettings(String blendId) async {
    await _delay(const Duration(milliseconds: 200));
    return {'id': blendId, 'name': 'Mock Blend', 'description': 'A mock blend', 'isPrivate': false};
  }

  @override
  Future<Map<String, dynamic>> getBlendActivity(String blendId, {int limit = 50, int offset = 0}) async {
    await _delay(const Duration(milliseconds: 300));
    return {
      'total': 2,
      'offset': offset,
      'limit': limit,
      'events': [
        {'id': 1, 'kind': 'swipe', 'description': 'Alice liked Classic Sneakers', 'userId': 'user1', 'createdAt': DateTime.now().toIso8601String()},
        {'id': 2, 'kind': 'member_joined', 'description': 'Bob joined the blend', 'userId': 'user2', 'createdAt': DateTime.now().toIso8601String()},
      ],
    };
  }
}