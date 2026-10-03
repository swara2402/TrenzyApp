import 'package:trenzy/models/friend.dart';
import 'package:image_picker/image_picker.dart';

/// Abstract interface shared by [ApiService] and [MockApiService].
///
/// Using this type in [apiServiceProvider] instead of `dynamic` gives us
/// compile-time safety: providers that consume the API service get autocomplete,
/// and mismatched method signatures are caught during development instead of
/// at runtime.
abstract class ApiServiceBase {
  // ---------- Auth ----------
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  );
  Future<Map<String, dynamic>?> googleLogin();
  Future<Map<String, dynamic>?> getCurrentUser();

  // ---------- Products ----------
  Future<Map<String, dynamic>> getProducts({
    String? category,
    String? subcategory,
    String? gender,
    String? color,
    String? season,
    String? brand,
    int offset = 0,
    int limit = 24,
  });
  Future<Map<String, dynamic>> getProduct(String productId);
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
  });
  Future<List<String>> getCategories();
  Future<List<String>> getSubcategories(String categoryName);
  Future<Map<String, dynamic>> getBrands({String? search});
  Future<void> archiveProduct(String productId);

  // ---------- Profile ----------
  Future<Map<String, dynamic>> updateProfile({required String name});

  // ---------- Wishlist ----------
  Future<Map<String, dynamic>> getWishlist();
  Future<void> setWishlist(List<String> productIds);

  // ---------- Cart ----------
  Future<Map<String, dynamic>> getCart();
  Future<Map<String, dynamic>> addCartItem({required String productId, int quantity = 1});
  Future<Map<String, dynamic>> updateCartItem({required String productId, required int quantity});
  Future<void> removeCartItem(String productId);
  Future<void> clearCart();

  // ---------- Suggestions ----------
  Future<List<dynamic>> getSuggestions(String query);

  // ---------- Decisions ----------
  Future<String> getReasoning({
    required String query,
    required String optionTitle,
    required String optionPrice,
    required int aiScore,
    required int socialApproval,
  });
  Future<void> saveDecision({
    required String query,
    required List<Map<String, dynamic>> selectedOptions,
    required String recommendedOptionId,
    required int socialApproval,
    required String reasoning,
  });
  Future<List<dynamic>> getDecisions();

  // ---------- Blend / Groups ----------
  Future<Map<String, dynamic>> createBlend({
    required String name,
    String? description,
    String? theme,
  });
  Future<void> inviteToBlend({
    required String blendId,
    required String inviterId,
    required String inviteeId,
  });
  Future<void> respondToBlendInvitation({
    required String invitationId,
    required String status,
  });
  Future<Map<String, dynamic>> joinBlend({required String groupId});
  Future<void> leaveBlend(String groupId);
  Future<Map<String, dynamic>> getBlendGroup(String groupId);
  Future<Map<String, dynamic>> getBlendResults(String groupId);
  Future<void> recordBlendSwipe({
    required String groupId,
    required String productId,
    required String swipeType,
  });
  Future<void> undoBlendSwipe({
    required String groupId,
    required String productId,
  });
  Future<List<dynamic>> getUserBlendGroups();

  // ---------- Group Messages ----------
  Future<Map<String, dynamic>> getGroupMessages({
    required String groupId,
    int limit = 50,
  });
  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  });

  // ---------- Notifications ----------
  Future<Map<String, dynamic>> getNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<Map<String, dynamic>> getUnreadNotificationCount();

  // ---------- Friends ----------
  Future<List<Friend>> getFriends();
  Future<void> sendFriendRequest({required String toFirebaseUid});
  Future<List<dynamic>> getFriendRequests({String box = 'incoming'});
  Future<void> acceptFriendRequest(int requestId);
  Future<void> rejectFriendRequest(int requestId);
  Future<void> removeFriend(int friendId);
  Future<List<FriendSuggestion>> getFriendSuggestions();

  // ---------- Invitations ----------
  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    int expiresInSeconds = 60 * 60 * 24 * 7,
  });
  Future<Map<String, dynamic>> acceptInvitation({required String token});

  // ---------- Trends ----------
  Future<List<dynamic>> getTrendingProducts({
    String? category,
    String? categories,
    String timeframe = 'daily',
    int limit = 20,
  });
  Future<List<dynamic>> getTrendPredictions({
    String? category,
    int limit = 10,
  });
  Future<void> trackProductView(String productId);
  Future<String?> trackAffiliateClick(String productId);
  Future<Map<String, dynamic>> aggregateTrends({
    String timeframe = 'daily',
  });

  // ---------- Campaigns ----------
  Future<Map<String, dynamic>?> getFeaturedCampaign();

  // ---------- Recommendations ----------
  Future<Map<String, dynamic>> getRecommendations();
  Future<Map<String, dynamic>> getRecommendedPeople({int limit = 10});
  Future<Map<String, dynamic>> getRecommendedOutfits({int limit = 6});
  Future<Map<String, dynamic>> getRecommendedProducts({
    int limit = 12,
    String? category,
  });

  // ---------- Wardrobe ----------
  Future<Map<String, dynamic>> getWardrobe({
    String? category,
    String? color,
    String? season,
    String? brand,
    bool favoriteOnly = false,
    String? search,
    int offset = 0,
    int limit = 50,
  });
  Future<Map<String, dynamic>> getWardrobeRecommendations({int limit = 5});
  Future<void> addWardrobeItem({
    required String name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
  });
  Future<void> updateWardrobeItem(
    int itemId, {
    String? name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
    bool? isFavorite,
  });
  Future<void> deleteWardrobeItem(int itemId);

  Future<String> uploadImage(XFile imageFile);

  // ---------- Outfits ----------
  Future<Map<String, dynamic>> getOutfits();
  Future<Map<String, dynamic>> createOutfit({
    required String name,
    required List<int> wardrobeItemIds,
    String? occasion,
  });
  Future<void> deleteOutfit(int outfitId);

  // ---------- Style Persona ----------
  Future<Map<String, dynamic>?> getPersona();
  Future<Map<String, dynamic>> generatePersona({Map<String, dynamic>? preferences});

  // ---------- User Preferences ----------
  Future<Map<String, dynamic>> getPreferences();
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
  });

  // ---------- Posts ----------
  Future<Map<String, dynamic>> createPost({
    required String content,
    String? attachment,
  });
  Future<Map<String, dynamic>> getUserPosts({
    String? userId,
    int offset = 0,
    int limit = 20,
  });
  Future<void> deletePost(int postId);
  Future<void> likePost(int postId);
  Future<void> unlikePost(int postId);
  Future<Map<String, dynamic>> commentOnPost(int postId, String content);
  Future<Map<String, dynamic>> getComments(int postId);

  // ---------- Feed ----------
  Future<Map<String, dynamic>> getFeed({int offset = 0, int limit = 20});
 
  // ---------- Direct Friend Chat ----------
  Future<Map<String, dynamic>> getDirectMessages({
    required String friendFirebaseUid,
    int limit = 50,
    int? beforeId,
  });
  Future<Map<String, dynamic>> sendDirectMessage({
    required String toFirebaseUid,
    required String message,
  });

  // ---------- Activity ----------
  Future<Map<String, dynamic>> getActivity({int limit = 20, int offset = 0});
  Future<void> createActivity({
    required String kind,
    required String description,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadataJson,
  });

  // ---------- Account ----------
  Future<void> deleteAccount();
  Future<void> reportIssue({required String category, required String description});
  Future<void> resetPassword(String email);

  // ---------- Batch Operations ----------
  Future<Map<String, dynamic>> getBatchProducts(List<String> ids);

  // ---------- Wishlist (individual) ----------
  Future<void> addWishlistItem(String productId);
  Future<void> removeWishlistItem(String productId);

  // ---------- Users ----------
  Future<Map<String, dynamic>> getUserProfile(String userId);

  // ---------- Follow ----------
  Future<void> followUser(String targetFirebaseUid);
  Future<void> unfollowUser(String targetFirebaseUid);
  Future<bool> getFollowStatus(String targetFirebaseUid);
  Future<Map<String, dynamic>> getFollowers();
  Future<Map<String, dynamic>> getFollowing();

  // ---------- Search ----------
  Future<Map<String, dynamic>> unifiedSearch(String query, {int limit = 10});

  // ---------- Push Notifications ----------
  Future<void> registerPushToken(String token, {String platform = 'fcm'});

  // ---------- Discover ----------
  Future<Map<String, dynamic>> discoverSwipe({int limit = 20});
  Future<void> recordDiscoverySwipe({required String productId, required String swipeType});

  // ---------- Blends ----------
  Future<void> disbandBlend(String groupId);

  // ---------- Blend Dashboard ----------
  Future<Map<String, dynamic>> getBlendDashboard(String blendId);

  // ---------- Shared Wishlist ----------
  Future<List<dynamic>> getSharedWishlist(String blendId, {String? sort, String? category, String? search});
  Future<Map<String, dynamic>> addToSharedWishlist(String blendId, {
    required String productId,
    String productName = '',
    double? productPrice,
    String? productImage,
    String? productBrand,
    String? productCategory,
    String? productUrl,
    String? notes,
  });
  Future<Map<String, dynamic>> updateWishlistItem(String blendId, int itemId, {String? notes, bool? isFavorite, String? purchaseLink});
  Future<void> removeFromSharedWishlist(String blendId, int itemId);

  // ---------- Moodboard ----------
  Future<List<dynamic>> getMoodboard(String blendId, {String? itemType});
  Future<Map<String, dynamic>> addToMoodboard(String blendId, {
    required String itemType,
    Map<String, dynamic>? content,
    String? imageUrl,
    String? caption,
  });
  Future<void> removeFromMoodboard(String blendId, int itemId);

  // ---------- Blend Insights ----------
  Future<List<dynamic>> getBlendInsights(String blendId, {bool refresh = false});
  Future<Map<String, dynamic>> refreshBlendInsights(String blendId);

  // ---------- Blend Settings ----------
  Future<void> updateBlendSettings(String blendId, {String? name, String? description, String? coverImage, bool? isPrivate});
  Future<Map<String, dynamic>> getBlendSettings(String blendId);

  // ---------- Blend Activity ----------
  Future<Map<String, dynamic>> getBlendActivity(String blendId, {int limit = 50, int offset = 0});

  // ---------- Outfits ----------
  Future<void> updateOutfit(int outfitId, {
    String? name,
    String? occasion,
    List<int>? wardrobeItemIds,
  });

  // ---------- Persona Onboarding ----------
  Future<List<String>> getPersonaStyles();
  Future<List<String>> getPersonaProductTypes();
  Future<List<Map<String, dynamic>>> getPersonaColors();

  // ---------- Payments ----------
  Future<Map<String, dynamic>> createPaymentOrder({
    required int amountPaise,
  });
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
  Future<Map<String, dynamic>> getPaymentOrderStatus({
    required String razorpayOrderId,
  });
}