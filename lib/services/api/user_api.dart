import 'api_client.dart';

class UserApi {
  UserApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    final data = await _client.patch('/users/me', body: {'name': name});
    _client.invalidateCache('currentUser');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyAge(DateTime dateOfBirth) async {
    final data = await _client.post('/users/me/age-verification', body: {
      'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
    });
    _client.invalidateCache('currentUser');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final data = await _client.get('/users/$userId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> deleteAccount() async {
    await _client.delete('/users/me');
    ApiClient.clearCache();
  }

  Future<void> reportIssue({
    required String category,
    required String description,
  }) async {
    await _client.post('/users/report', body: {
      'category': category,
      'description': description,
    });
  }

  // ---------- Style Persona ----------
  Future<Map<String, dynamic>?> getPersona() async {
    final data = await _client.get('/persona');
    return data is Map<String, dynamic> ? data : null;
  }

  Future<Map<String, dynamic>> generatePersona({
    Map<String, dynamic>? preferences,
  }) async {
    final data = await _client.post('/persona/generate', body: preferences);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- User Preferences ----------
  Future<Map<String, dynamic>> getPreferences() async {
    final data = await _client.get('/persona/preferences');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

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
  }) async {
    final body = <String, dynamic>{};
    if (preferredCategories != null) body['preferred_categories'] = preferredCategories;
    if (preferredBrands != null) body['preferred_brands'] = preferredBrands;
    if (preferredColors != null) body['preferred_colors'] = preferredColors;
    if (preferredSeasons != null) body['preferred_seasons'] = preferredSeasons;
    if (preferredStyles != null) body['preferred_styles'] = preferredStyles;
    if (preferredAesthetics != null) body['preferred_aesthetics'] = preferredAesthetics;
    if (preferredOccasions != null) body['preferred_occasions'] = preferredOccasions;
    if (budgetMax != null) body['budget_max'] = budgetMax;
    if (discoverPreferences != null) body['discover_preferences'] = discoverPreferences;
    if (productInterests != null) body['product_interests'] = productInterests;
    if (shoppingPriorities != null) body['shopping_priorities'] = shoppingPriorities;

    await _client.post('/persona/preferences', body: body);
  }

  // ---------- Persona Onboarding Constants ----------
  Future<List<String>> getPersonaStyles() async {
    final data = await _client.get('/persona/styles');
    if (data is List) return data.map((e) => e.toString()).toList();
    if (data is Map<String, dynamic> && data['styles'] is List) {
      return (data['styles'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<String>> getPersonaProductTypes() async {
    final data = await _client.get('/persona/product-types');
    if (data is List) return data.map((e) => e.toString()).toList();
    if (data is Map<String, dynamic> && data['product_types'] is List) {
      return (data['product_types'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPersonaColors() async {
    final data = await _client.get('/persona/colors');
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic> && data['colors'] is List) {
      return (data['colors'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
