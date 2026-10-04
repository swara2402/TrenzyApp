import 'api_client.dart';

class RecommendationApi {
  RecommendationApi(this._client);
  final ApiClient _client;

  // ---------- Recommendations ----------
  Future<Map<String, dynamic>> getRecommendations() async {
    final data = await _client.get('/recommendations');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRecommendedPeople({int limit = 10}) async {
    final data = await _client.get('/recommend/people', queryParams: {
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRecommendedOutfits({int limit = 6}) async {
    final data = await _client.get('/recommend/outfits', queryParams: {
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRecommendedProducts({
    int limit = 12,
    String? category,
  }) async {
    final qp = <String, String>{'limit': limit.toString()};
    if (category != null && category.isNotEmpty) qp['category'] = category;
    final data = await _client.get('/recommend/products', queryParams: qp);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Discover Swipes ----------
  Future<Map<String, dynamic>> discoverSwipe({int limit = 20}) async {
    final data = await _client.get('/recommendations/discover/swipe', queryParams: {
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> recordDiscoverySwipe({
    required String productId,
    required String swipeType,
  }) async {
    await _client.post('/recommendations/discover/swipe', body: {
      'productId': productId,
      'swipeType': swipeType,
    });
  }

  // ---------- Trends ----------
  Future<List<dynamic>> getTrendingProducts({
    String? category,
    String? categories,
    String timeframe = 'daily',
    int limit = 20,
  }) async {
    final qp = <String, String>{
      'timeframe': timeframe,
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty) qp['category'] = category;
    if (categories != null && categories.isNotEmpty) qp['categories'] = categories;

    final data = await _client.get('/trends', queryParams: qp);
    if (data is Map<String, dynamic> && data['trends'] is List) {
      return data['trends'] as List<dynamic>;
    }
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> getTrendPredictions({
    String? category,
    int limit = 10,
  }) async {
    final qp = <String, String>{'limit': limit.toString()};
    if (category != null && category.isNotEmpty) qp['category'] = category;

    final data = await _client.get('/trends/predictions', queryParams: qp);
    if (data is Map<String, dynamic> && data['predictions'] is List) {
      return data['predictions'] as List<dynamic>;
    }
    if (data is List) return data;
    return [];
  }

  Future<void> trackProductView(String productId) async {
    await _client.post('/trends/track-view', body: {'product_id': productId});
  }

  Future<String?> trackAffiliateClick(String productId) async {
    final data = await _client.post('/trends/affiliate-click', body: {'product_id': productId});
    if (data is Map<String, dynamic>) {
      return data['affiliate_link']?.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>> aggregateTrends({String timeframe = 'daily'}) async {
    final data = await _client.post('/trends/aggregate', body: {'timeframe': timeframe});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Decisions ----------
  Future<String> getReasoning({
    required String query,
    required String optionTitle,
    required String optionPrice,
    required int aiScore,
    required int socialApproval,
  }) async {
    final data = await _client.post('/decisions/reasoning', body: {
      'query': query,
      'option_title': optionTitle,
      'option_price': optionPrice,
      'ai_score': aiScore,
      'social_approval': socialApproval,
    });
    if (data is Map<String, dynamic>) {
      return data['reasoning']?.toString() ?? 'Recommended choice based on preferences.';
    }
    return 'Recommended choice based on preferences.';
  }

  Future<void> saveDecision({
    required String query,
    required List<Map<String, dynamic>> selectedOptions,
    required String recommendedOptionId,
    required int socialApproval,
    required String reasoning,
  }) async {
    await _client.post('/decisions', body: {
      'query': query,
      'selected_options': selectedOptions,
      'recommended_option_id': recommendedOptionId,
      'social_approval': socialApproval,
      'reasoning': reasoning,
    });
  }

  Future<List<dynamic>> getDecisions() async {
    final data = await _client.get('/decisions');
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['decisions'] is List) {
      return data['decisions'] as List<dynamic>;
    }
    return [];
  }

  // ---------- Campaigns ----------
  Future<Map<String, dynamic>?> getFeaturedCampaign() async {
    final data = await _client.get('/campaigns/featured');
    return data is Map<String, dynamic> ? data : null;
  }
}
