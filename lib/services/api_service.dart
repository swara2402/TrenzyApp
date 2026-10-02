import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/friend.dart';
import 'api_service_base.dart';
import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/product_api.dart';
import 'api/cart_api.dart';
import 'api/wishlist_api.dart';
import 'api/wardrobe_api.dart';
import 'api/blend_api.dart';
import 'api/social_api.dart';
import 'api/payment_api.dart';
import 'api/recommendation_api.dart';
import 'api/notification_api.dart';
import 'api/user_api.dart';

export 'api/api_client.dart';
export 'api/auth_api.dart';
export 'api/product_api.dart';
export 'api/cart_api.dart';
export 'api/wishlist_api.dart';
export 'api/wardrobe_api.dart';
export 'api/blend_api.dart';
export 'api/social_api.dart';
export 'api/payment_api.dart';
export 'api/recommendation_api.dart';
export 'api/notification_api.dart';
export 'api/user_api.dart';

/// Modular API service implementation following domain-driven design.
///
/// Implements [ApiServiceBase] by delegating to domain-specific API clients
/// (`AuthApi`, `ProductApi`, `CartApi`, `WishlistApi`, `WardrobeApi`, `BlendApi`,
/// `SocialApi`, `PaymentApi`, `RecommendationApi`, `NotificationApi`, `UserApi`).
class ApiService implements ApiServiceBase {
  ApiService({
    required this.firebaseAuth,
    http.Client? client,
  })  : _client = ApiClient(firebaseAuth: firebaseAuth, client: client),
        _authApi = AuthApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _productApi = ProductApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _cartApi = CartApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _wishlistApi = WishlistApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _wardrobeApi = WardrobeApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _blendApi = BlendApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _socialApi = SocialApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _paymentApi = PaymentApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _recommendationApi = RecommendationApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _notificationApi = NotificationApi(ApiClient(firebaseAuth: firebaseAuth, client: client)),
        _userApi = UserApi(ApiClient(firebaseAuth: firebaseAuth, client: client));

  final FirebaseAuth firebaseAuth;
  final ApiClient _client;

  ApiClient get client => _client;

  final AuthApi _authApi;
  final ProductApi _productApi;
  final CartApi _cartApi;
  final WishlistApi _wishlistApi;
  final WardrobeApi _wardrobeApi;
  final BlendApi _blendApi;
  final SocialApi _socialApi;
  final PaymentApi _paymentApi;
  final RecommendationApi _recommendationApi;
  final NotificationApi _notificationApi;
  final UserApi _userApi;

  // Domain API getters for modular access
  AuthApi get auth => _authApi;
  ProductApi get products => _productApi;
  CartApi get cart => _cartApi;
  WishlistApi get wishlist => _wishlistApi;
  WardrobeApi get wardrobe => _wardrobeApi;
  BlendApi get blends => _blendApi;
  SocialApi get social => _socialApi;
  PaymentApi get payments => _paymentApi;
  RecommendationApi get recommendations => _recommendationApi;
  NotificationApi get notifications => _notificationApi;
  UserApi get user => _userApi;

  // Global static hooks & utilities
  static void Function()? get onSessionExpired => ApiClient.onSessionExpired;
  static set onSessionExpired(void Function()? handler) => ApiClient.onSessionExpired = handler;

  static void clearCache() => ApiClient.clearCache();
  static String? resolveImageUrl(String? imageUrl) => ApiClient.resolveImageUrl(imageUrl);
  static String get socketBaseUrl => ApiClient.socketBaseUrl;

  // ---------- Auth ----------
  @override
  Future<Map<String, dynamic>> login(String email, String password) => _authApi.login(email, password);

  @override
  Future<Map<String, dynamic>> signup(String name, String email, String password) =>
      _authApi.signup(name, email, password);

  @override
  Future<Map<String, dynamic>?> googleLogin() => _authApi.googleLogin();

  @override
  Future<Map<String, dynamic>?> getCurrentUser() => _authApi.getCurrentUser();

  // ---------- Products ----------
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
  }) =>
      _productApi.getProducts(
        category: category,
        subcategory: subcategory,
        gender: gender,
        color: color,
        season: season,
        brand: brand,
        offset: offset,
        limit: limit,
      );

  @override
  Future<Map<String, dynamic>> getProduct(String productId) => _productApi.getProduct(productId);

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
  }) =>
      _productApi.searchProducts(
        query: query,
        category: category,
        subcategory: subcategory,
        gender: gender,
        color: color,
        season: season,
        brand: brand,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sort: sort,
      );

  @override
  Future<List<String>> getCategories() => _productApi.getCategories();

  @override
  Future<List<String>> getSubcategories(String categoryName) => _productApi.getSubcategories(categoryName);

  @override
  Future<Map<String, dynamic>> getBrands({String? search}) => _productApi.getBrands(search: search);

  @override
  Future<void> archiveProduct(String productId) => _productApi.archiveProduct(productId);

  @override
  Future<Map<String, dynamic>> getBatchProducts(List<String> ids) => _productApi.getBatchProducts(ids);

  @override
  Future<Map<String, dynamic>> unifiedSearch(String query, {int limit = 10}) =>
      _productApi.unifiedSearch(query, limit: limit);

  @override
  Future<List<dynamic>> getSuggestions(String query) => _productApi.getSuggestions(query);

  // ---------- Cart ----------
  @override
  Future<Map<String, dynamic>> getCart() => _cartApi.getCart();

  @override
  Future<Map<String, dynamic>> addCartItem({required String productId, int quantity = 1}) =>
      _cartApi.addCartItem(productId: productId, quantity: quantity);

  @override
  Future<Map<String, dynamic>> updateCartItem({required String productId, required int quantity}) =>
      _cartApi.updateCartItem(productId: productId, quantity: quantity);

  @override
  Future<void> removeCartItem(String productId) => _cartApi.removeCartItem(productId);

  @override
  Future<void> clearCart() => _cartApi.clearCart();

  // ---------- Wishlist ----------
  @override
  Future<Map<String, dynamic>> getWishlist() => _wishlistApi.getWishlist();

  @override
  Future<void> setWishlist(List<String> productIds) => _wishlistApi.setWishlist(productIds);

  @override
  Future<void> addWishlistItem(String productId) => _wishlistApi.addWishlistItem(productId);

  @override
  Future<void> removeWishlistItem(String productId) => _wishlistApi.removeWishlistItem(productId);

  // ---------- Wardrobe & Outfits ----------
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
  }) =>
      _wardrobeApi.getWardrobe(
        category: category,
        color: color,
        season: season,
        brand: brand,
        favoriteOnly: favoriteOnly,
        search: search,
        offset: offset,
        limit: limit,
      );

  @override
  Future<Map<String, dynamic>> getWardrobeRecommendations({int limit = 5}) =>
      _wardrobeApi.getWardrobeRecommendations(limit: limit);

  @override
  Future<void> addWardrobeItem({
    required String name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
  }) =>
      _wardrobeApi.addWardrobeItem(
        name: name,
        imageUrl: imageUrl,
        category: category,
        color: color,
        season: season,
        brand: brand,
      );

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
  }) =>
      _wardrobeApi.updateWardrobeItem(
        itemId,
        name: name,
        imageUrl: imageUrl,
        category: category,
        color: color,
        season: season,
        brand: brand,
        isFavorite: isFavorite,
      );

  @override
  Future<void> deleteWardrobeItem(int itemId) => _wardrobeApi.deleteWardrobeItem(itemId);

  @override
  Future<String> uploadImage(XFile imageFile) => _wardrobeApi.uploadImage(imageFile);

  @override
  Future<Map<String, dynamic>> getOutfits() => _wardrobeApi.getOutfits();

  @override
  Future<Map<String, dynamic>> createOutfit({
    required String name,
    required List<int> wardrobeItemIds,
    String? occasion,
  }) =>
      _wardrobeApi.createOutfit(
        name: name,
        wardrobeItemIds: wardrobeItemIds,
        occasion: occasion,
      );

  @override
  Future<void> updateOutfit(
    int outfitId, {
    String? name,
    String? occasion,
    List<int>? wardrobeItemIds,
  }) =>
      _wardrobeApi.updateOutfit(
        outfitId,
        name: name,
        occasion: occasion,
        wardrobeItemIds: wardrobeItemIds,
      );

  @override
  Future<void> deleteOutfit(int outfitId) => _wardrobeApi.deleteOutfit(outfitId);

  // ---------- Blends & Shared Features ----------
  @override
  Future<Map<String, dynamic>> createBlend({
    required String name,
    String? description,
    String? theme,
  }) =>
      _blendApi.createBlend(name: name, description: description, theme: theme);

  @override
  Future<void> inviteToBlend({
    required String blendId,
    required String inviterId,
    required String inviteeId,
  }) =>
      _blendApi.inviteToBlend(blendId: blendId, inviterId: inviterId, inviteeId: inviteeId);

  @override
  Future<void> respondToBlendInvitation({
    required String invitationId,
    required String status,
  }) =>
      _blendApi.respondToBlendInvitation(invitationId: invitationId, status: status);

  @override
  Future<Map<String, dynamic>> joinBlend({required String groupId}) =>
      _blendApi.joinBlend(groupId: groupId);

  @override
  Future<void> leaveBlend(String groupId) => _blendApi.leaveBlend(groupId);

  @override
  Future<Map<String, dynamic>> getBlendGroup(String groupId) => _blendApi.getBlendGroup(groupId);

  @override
  Future<Map<String, dynamic>> getBlendResults(String groupId) => _blendApi.getBlendResults(groupId);

  @override
  Future<void> recordBlendSwipe({
    required String groupId,
    required String productId,
    required String swipeType,
  }) =>
      _blendApi.recordBlendSwipe(groupId: groupId, productId: productId, swipeType: swipeType);

  @override
  Future<void> undoBlendSwipe({
    required String groupId,
    required String productId,
  }) =>
      _blendApi.undoBlendSwipe(groupId: groupId, productId: productId);

  @override
  Future<List<dynamic>> getUserBlendGroups() => _blendApi.getUserBlendGroups();

  @override
  Future<void> disbandBlend(String groupId) => _blendApi.disbandBlend(groupId);

  @override
  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) =>
      _blendApi.createInvitation(groupId: groupId, expiresInSeconds: expiresInSeconds);

  @override
  Future<Map<String, dynamic>> acceptInvitation({required String token}) =>
      _blendApi.acceptInvitation(token: token);

  @override
  Future<Map<String, dynamic>> getBlendDashboard(String blendId) =>
      _blendApi.getBlendDashboard(blendId);

  @override
  Future<List<dynamic>> getSharedWishlist(
    String blendId, {
    String? sort,
    String? category,
    String? search,
  }) =>
      _blendApi.getSharedWishlist(blendId, sort: sort, category: category, search: search);

  @override
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
  }) =>
      _blendApi.addToSharedWishlist(
        blendId,
        productId: productId,
        productName: productName,
        productPrice: productPrice,
        productImage: productImage,
        productBrand: productBrand,
        productCategory: productCategory,
        productUrl: productUrl,
        notes: notes,
      );

  @override
  Future<Map<String, dynamic>> updateWishlistItem(
    String blendId,
    int itemId, {
    String? notes,
    bool? isFavorite,
    String? purchaseLink,
  }) =>
      _blendApi.updateWishlistItem(
        blendId,
        itemId,
        notes: notes,
        isFavorite: isFavorite,
        purchaseLink: purchaseLink,
      );

  @override
  Future<void> removeFromSharedWishlist(String blendId, int itemId) =>
      _blendApi.removeFromSharedWishlist(blendId, itemId);

  @override
  Future<List<dynamic>> getMoodboard(String blendId, {String? itemType}) =>
      _blendApi.getMoodboard(blendId, itemType: itemType);

  @override
  Future<Map<String, dynamic>> addToMoodboard(
    String blendId, {
    required String itemType,
    Map<String, dynamic>? content,
    String? imageUrl,
    String? caption,
  }) =>
      _blendApi.addToMoodboard(
        blendId,
        itemType: itemType,
        content: content,
        imageUrl: imageUrl,
        caption: caption,
      );

  @override
  Future<void> removeFromMoodboard(String blendId, int itemId) =>
      _blendApi.removeFromMoodboard(blendId, itemId);

  @override
  Future<List<dynamic>> getBlendInsights(String blendId, {bool refresh = false}) =>
      _blendApi.getBlendInsights(blendId, refresh: refresh);

  @override
  Future<Map<String, dynamic>> refreshBlendInsights(String blendId) =>
      _blendApi.refreshBlendInsights(blendId);

  @override
  Future<void> updateBlendSettings(
    String blendId, {
    String? name,
    String? description,
    String? coverImage,
    bool? isPrivate,
  }) =>
      _blendApi.updateBlendSettings(
        blendId,
        name: name,
        description: description,
        coverImage: coverImage,
        isPrivate: isPrivate,
      );

  @override
  Future<Map<String, dynamic>> getBlendSettings(String blendId) =>
      _blendApi.getBlendSettings(blendId);

  @override
  Future<Map<String, dynamic>> getBlendActivity(
    String blendId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _blendApi.getBlendActivity(blendId, limit: limit, offset: offset);

  // ---------- Social, Friends, Posts, Feed ----------
  @override
  Future<List<Friend>> getFriends() => _socialApi.getFriends();

  @override
  Future<void> sendFriendRequest({required String toFirebaseUid}) =>
      _socialApi.sendFriendRequest(toFirebaseUid: toFirebaseUid);

  @override
  Future<List<dynamic>> getFriendRequests({String box = 'incoming'}) =>
      _socialApi.getFriendRequests(box: box);

  @override
  Future<void> acceptFriendRequest(int requestId) => _socialApi.acceptFriendRequest(requestId);

  @override
  Future<void> rejectFriendRequest(int requestId) => _socialApi.rejectFriendRequest(requestId);

  @override
  Future<void> removeFriend(int friendId) => _socialApi.removeFriend(friendId);

  @override
  Future<List<FriendSuggestion>> getFriendSuggestions() => _socialApi.getFriendSuggestions();

  @override
  Future<void> followUser(String targetFirebaseUid) => _socialApi.followUser(targetFirebaseUid);

  @override
  Future<void> unfollowUser(String targetFirebaseUid) => _socialApi.unfollowUser(targetFirebaseUid);

  @override
  Future<bool> getFollowStatus(String targetFirebaseUid) =>
      _socialApi.getFollowStatus(targetFirebaseUid);

  @override
  Future<Map<String, dynamic>> getFollowers() => _socialApi.getFollowers();

  @override
  Future<Map<String, dynamic>> getFollowing() => _socialApi.getFollowing();

  @override
  Future<Map<String, dynamic>> createPost({required String content, String? attachment}) =>
      _socialApi.createPost(content: content, attachment: attachment);

  @override
  Future<Map<String, dynamic>> getUserPosts({String? userId, int offset = 0, int limit = 20}) =>
      _socialApi.getUserPosts(userId: userId, offset: offset, limit: limit);

  @override
  Future<void> deletePost(int postId) => _socialApi.deletePost(postId);

  @override
  Future<void> likePost(int postId) => _socialApi.likePost(postId);

  @override
  Future<void> unlikePost(int postId) => _socialApi.unlikePost(postId);

  @override
  Future<Map<String, dynamic>> commentOnPost(int postId, String content) =>
      _socialApi.commentOnPost(postId, content);

  @override
  Future<Map<String, dynamic>> getComments(int postId) => _socialApi.getComments(postId);

  @override
  Future<Map<String, dynamic>> getFeed({int offset = 0, int limit = 20}) =>
      _socialApi.getFeed(offset: offset, limit: limit);

  @override
  Future<Map<String, dynamic>> getGroupMessages({required String groupId, int limit = 50}) =>
      _socialApi.getGroupMessages(groupId: groupId, limit: limit);

  @override
  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  }) =>
      _socialApi.sendGroupMessage(
        groupId: groupId,
        message: message,
        attachedProductId: attachedProductId,
        attachedProductTitle: attachedProductTitle,
        attachedProductImage: attachedProductImage,
        attachedProductPrice: attachedProductPrice,
      );

  @override
  Future<Map<String, dynamic>> getActivity({int limit = 20, int offset = 0}) =>
      _socialApi.getActivity(limit: limit, offset: offset);

  @override
  Future<void> createActivity({
    required String kind,
    required String description,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadataJson,
  }) =>
      _socialApi.createActivity(
        kind: kind,
        description: description,
        targetId: targetId,
        targetType: targetType,
        metadataJson: metadataJson,
      );

  // ---------- Recommendations, Trends & Discovery ----------
  @override
  Future<Map<String, dynamic>> getRecommendations() => _recommendationApi.getRecommendations();

  @override
  Future<Map<String, dynamic>> getRecommendedPeople({int limit = 10}) =>
      _recommendationApi.getRecommendedPeople(limit: limit);

  @override
  Future<Map<String, dynamic>> getRecommendedOutfits({int limit = 6}) =>
      _recommendationApi.getRecommendedOutfits(limit: limit);

  @override
  Future<Map<String, dynamic>> getRecommendedProducts({int limit = 12, String? category}) =>
      _recommendationApi.getRecommendedProducts(limit: limit, category: category);

  @override
  Future<Map<String, dynamic>> discoverSwipe({int limit = 20}) =>
      _recommendationApi.discoverSwipe(limit: limit);

  @override
  Future<void> recordDiscoverySwipe({required String productId, required String swipeType}) =>
      _recommendationApi.recordDiscoverySwipe(productId: productId, swipeType: swipeType);

  @override
  Future<List<dynamic>> getTrendingProducts({
    String? category,
    String? categories,
    String timeframe = 'daily',
    int limit = 20,
  }) =>
      _recommendationApi.getTrendingProducts(
        category: category,
        categories: categories,
        timeframe: timeframe,
        limit: limit,
      );

  @override
  Future<List<dynamic>> getTrendPredictions({String? category, int limit = 10}) =>
      _recommendationApi.getTrendPredictions(category: category, limit: limit);

  @override
  Future<void> trackProductView(String productId) => _recommendationApi.trackProductView(productId);

  @override
  Future<String?> trackAffiliateClick(String productId) =>
      _recommendationApi.trackAffiliateClick(productId);

  @override
  Future<Map<String, dynamic>> aggregateTrends({String timeframe = 'daily'}) =>
      _recommendationApi.aggregateTrends(timeframe: timeframe);

  @override
  Future<String> getReasoning({
    required String query,
    required String optionTitle,
    required String optionPrice,
    required int aiScore,
    required int socialApproval,
  }) =>
      _recommendationApi.getReasoning(
        query: query,
        optionTitle: optionTitle,
        optionPrice: optionPrice,
        aiScore: aiScore,
        socialApproval: socialApproval,
      );

  @override
  Future<void> saveDecision({
    required String query,
    required List<Map<String, dynamic>> selectedOptions,
    required String recommendedOptionId,
    required int socialApproval,
    required String reasoning,
  }) =>
      _recommendationApi.saveDecision(
        query: query,
        selectedOptions: selectedOptions,
        recommendedOptionId: recommendedOptionId,
        socialApproval: socialApproval,
        reasoning: reasoning,
      );

  @override
  Future<List<dynamic>> getDecisions() => _recommendationApi.getDecisions();

  @override
  Future<Map<String, dynamic>?> getFeaturedCampaign() =>
      _recommendationApi.getFeaturedCampaign();

  // ---------- Notifications ----------
  @override
  Future<Map<String, dynamic>> getNotifications() => _notificationApi.getNotifications();

  @override
  Future<void> markNotificationRead(String notificationId) =>
      _notificationApi.markNotificationRead(notificationId);

  @override
  Future<void> markAllNotificationsRead() =>
      _notificationApi.markAllNotificationsRead();

  @override
  Future<Map<String, dynamic>> getUnreadNotificationCount() =>
      _notificationApi.getUnreadNotificationCount();

  @override
  Future<void> registerPushToken(String token, {String platform = 'fcm'}) =>
      _notificationApi.registerPushToken(token, platform: platform);

  // ---------- User, Persona & Account ----------
  @override
  Future<Map<String, dynamic>> updateProfile({required String name}) =>
      _userApi.updateProfile(name: name);

  @override
  Future<Map<String, dynamic>> getUserProfile(String userId) =>
      _userApi.getUserProfile(userId);

  @override
  Future<void> deleteAccount() => _userApi.deleteAccount();

  @override
  Future<void> reportIssue({required String category, required String description}) =>
      _userApi.reportIssue(category: category, description: description);

  @override
  Future<void> resetPassword(String email) => _authApi.resetPassword(email);

  @override
  Future<Map<String, dynamic>?> getPersona() => _userApi.getPersona();

  @override
  Future<Map<String, dynamic>> generatePersona({Map<String, dynamic>? preferences}) =>
      _userApi.generatePersona(preferences: preferences);

  @override
  Future<Map<String, dynamic>> getPreferences() => _userApi.getPreferences();

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
  }) =>
      _userApi.savePreferences(
        preferredCategories: preferredCategories,
        preferredBrands: preferredBrands,
        preferredColors: preferredColors,
        preferredSeasons: preferredSeasons,
        preferredStyles: preferredStyles,
        preferredAesthetics: preferredAesthetics,
        preferredOccasions: preferredOccasions,
        budgetMax: budgetMax,
        discoverPreferences: discoverPreferences,
        productInterests: productInterests,
        shoppingPriorities: shoppingPriorities,
      );

  @override
  Future<List<String>> getPersonaStyles() => _userApi.getPersonaStyles();

  @override
  Future<List<String>> getPersonaProductTypes() => _userApi.getPersonaProductTypes();

  @override
  Future<List<Map<String, dynamic>>> getPersonaColors() => _userApi.getPersonaColors();

  // ---------- Payments ----------
  @override
  Future<Map<String, dynamic>> createPaymentOrder({required int amountPaise}) =>
      _paymentApi.createPaymentOrder(amountPaise: amountPaise);

  @override
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      _paymentApi.verifyPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );

  @override
  Future<Map<String, dynamic>> getPaymentOrderStatus({
    required String razorpayOrderId,
  }) =>
      _paymentApi.getPaymentOrderStatus(razorpayOrderId: razorpayOrderId);
}