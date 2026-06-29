import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'environment_config.dart' show EnvConfig;
import '../models/api_exception.dart';

class ApiService {
  static void Function()? onSessionExpired;

  ApiService({required this.firebaseAuth});

  final FirebaseAuth firebaseAuth;

  static String get _baseUrl => EnvConfig.httpBaseUrl;
  static String get socketBaseUrl => EnvConfig.socketBaseUrl;

  static const _timeout = Duration(seconds: 20);
  static const int _maxRetries = 2;

  Future<String?> _getToken() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(false);
    } catch (_) {
      try {
        return await user.getIdToken(true);
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final String? token = await _getToken();
    return {
      'Content-Type': 'application/json',
      ...(token?.isNotEmpty == true
          ? <String, String>{'Authorization': 'Bearer $token'}
          : const <String, String>{}),
    };
  }

  static void _clearSessionAndRedirect() {
    FirebaseAuth.instance.signOut();
    onSessionExpired?.call();
  }

  String _handleHttpResponse(http.Response response) {
    if (response.statusCode == 401) {
      _clearSessionAndRedirect();
      throw const ApiException('Session expired. Please sign in again.');
    }
    if (response.statusCode == 403) {
      throw const ApiException('You do not have permission for this action.');
    }
    if (response.statusCode == 404) {
      throw const ApiException('The requested resource was not found.');
    }
    if (response.statusCode == 429) {
      throw const ApiException('Too many requests. Please try again later.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail'] ?? body['message'] ?? detail;
      } on FormatException {
        detail = response.body.isNotEmpty
            ? '${response.statusCode}: ${response.body}'
            : detail;
      } catch (_) {
        detail = response.body.isNotEmpty
            ? '${response.statusCode}: ${response.body}'
            : detail;
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return response.body;
  }

  Future<http.Response> _get(String path, {int retries = 0}) async {
    final headers = await _getHeaders();
    try {
      final response = await http
          .get(Uri.parse(path), headers: headers)
          .timeout(_timeout);
      _handleHttpResponse(response);
      return response;
    } on TimeoutException {
      if (retries < _maxRetries) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return _get(path, retries: retries + 1);
      }
      throw const ApiException(
        'Request timed out. Please check your connection.',
      );
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http
        .post(Uri.parse(path), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    _handleHttpResponse(response);
    return response;
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http
        .put(Uri.parse(path), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    _handleHttpResponse(response);
    return response;
  }

  Future<http.Response> _delete(String path) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(Uri.parse(path), headers: headers)
        .timeout(_timeout);
    _handleHttpResponse(response);
    return response;
  }

  dynamic _decodeResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ApiException('Invalid response from server.', details: e);
    }
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final headers = {'Content-Type': 'application/json'};
    final response = await http
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    _handleHttpResponse(response);
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    final headers = {'Content-Type': 'application/json'};
    final response = await http
        .post(
          Uri.parse('$_baseUrl/auth/signup'),
          headers: headers,
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(_timeout);
    _handleHttpResponse(response);
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  /// Verifies a Firebase ID token (from Google sign-in) and upserts
  /// the corresponding backend user.
  Future<Map<String, dynamic>?> googleLogin() async {
    final response = await _post('$_baseUrl/auth/google-login', {});
    return _decodeResponse(response) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final headers = await _getHeaders();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/auth/me'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        _clearSessionAndRedirect();
        return null;
      }
      if (response.statusCode == 200) {
        final body = _decodeResponse(response) as Map<String, dynamic>;
        // Backend returns {"user": {...}} — unwrap the nested object.
        return body['user'] as Map<String, dynamic>? ?? body;
      }
    } catch (_) {
      // Backend unreachable — caller falls back to Firebase profile.
    }
    return null;
  }

  // Products
  Future<List<dynamic>> getProducts({String? category}) async {
    final url = category != null
        ? '$_baseUrl/products?category=$category'
        : '$_baseUrl/products';
    final response = await _get(url);
    return _decodeResponse(response) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    final response = await _get('$_baseUrl/products/$productId');
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchProducts({
    required String query,
    String? category,
    int? minPrice,
    int? maxPrice,
    String? sort,
  }) async {
    final params = <String, String>{'q': query};
    if (category != null) params['category'] = category;
    if (minPrice != null) params['minPrice'] = minPrice.toString();
    if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
    if (sort == null || sort.isEmpty) {
      // no sort
    } else {
      params['sort'] = sort;
    }
    final uri = Uri.parse(
      '$_baseUrl/products/search',
    ).replace(queryParameters: params);
    final response = await _get(uri.toString());
    return _decodeResponse(response) as List<dynamic>;
  }

  Future<List<String>> getCategories() async {
    final response = await _get('$_baseUrl/categories');
    final body = _decodeResponse(response) as List<dynamic>;
    return List<String>.from(body);
  }

  // Profile
  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    final response = await _put('$_baseUrl/auth/profile', {'name': name});
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  // Wishlist
  Future<Map<String, dynamic>> getWishlist() async {
    final response = await _get('$_baseUrl/wishlist');
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> setWishlist(List<String> productIds) async {
    await _post('$_baseUrl/wishlist', {'productIds': productIds});
  }

  // Suggestions
  Future<List<dynamic>> getSuggestions(String query) async {
    final response = await _get(
      '$_baseUrl/suggestions?query=${Uri.encodeComponent(query)}',
    );
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['suggestions'] ?? [];
  }

  // Decisions
  Future<String> getReasoning({
    required String query,
    required String optionTitle,
    required String optionPrice,
    required int aiScore,
    required int socialApproval,
  }) async {
    final response = await _post('$_baseUrl/decisions/reasoning', {
      'query': query,
      'optionTitle': optionTitle,
      'optionPrice': optionPrice,
      'aiScore': aiScore,
      'socialApproval': socialApproval,
    });
    final decoded = _decodeResponse(response);
    if (decoded is Map) {
      final reasoning = decoded['reasoning'];
      return reasoning?.toString() ?? decoded.toString();
    }
    return decoded.toString();
  }

  Future<void> saveDecision({
    required String query,
    required List<Map<String, dynamic>> selectedOptions,
    required String recommendedOptionId,
    required int socialApproval,
    required String reasoning,
  }) async {
    await _post('$_baseUrl/decisions/decisions', {
      'query': query,
      'selectedOptions': selectedOptions,
      'recommendedOptionId': recommendedOptionId,
      'socialApproval': socialApproval,
      'reasoning': reasoning,
    });
  }

  Future<List<dynamic>> getDecisions() async {
    final response = await _get('$_baseUrl/decisions');
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['decisions'] ?? [];
  }

  // Blend/Groups
  Future<Map<String, dynamic>> createBlend({required String name}) async {
    final response = await _post('$_baseUrl/groups', {'name': name});
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> joinBlend({required String groupId}) async {
    await _post('$_baseUrl/groups/join', {'groupId': groupId});
  }

  Future<void> leaveBlend(String groupId) async {
    await _delete('$_baseUrl/groups/$groupId/leave');
  }

  Future<Map<String, dynamic>> getBlendGroup(String groupId) async {
    final response = await _get('$_baseUrl/groups/$groupId');
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBlendResults(String groupId) async {
    final response = await _get('$_baseUrl/groups/$groupId/results');
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> recordBlendSwipe({
    required String groupId,
    required String productId,
    required String swipeType,
  }) async {
    await _post('$_baseUrl/groups/swipe', {
      'groupId': groupId,
      'productId': productId,
      'swipeType': swipeType,
    });
  }

  Future<List<dynamic>> getUserBlendGroups() async {
    final response = await _get('$_baseUrl/groups');
    return _decodeResponse(response) as List<dynamic>;
  }

  // Group Messages
  Future<Map<String, dynamic>> getGroupMessages({
    required String groupId,
    int limit = 50,
  }) async {
    final response = await _get(
      '$_baseUrl/groups/$groupId/messages?limit=$limit',
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  }) async {
    final body = <String, dynamic>{
      'groupId': groupId,
      'message': message,
      'attachedProductId': attachedProductId,
      'attachedProductTitle': attachedProductTitle,
      'attachedProductImage': attachedProductImage,
      'attachedProductPrice': attachedProductPrice,
    }..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    await _post('$_baseUrl/groups/messages/send', body);
  }

  // Notifications
  Future<Map<String, dynamic>> getNotifications() async {
    final response = await _get('$_baseUrl/notifications');
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final response = await _put(
      '$_baseUrl/notifications/$notificationId/read',
      {},
    );
    _handleHttpResponse(response);
  }

  // Friends
  Future<List<dynamic>> getFriends() async {
    final response = await _get('$_baseUrl/friends');
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['friends'] ?? [];
  }

  Future<void> sendFriendRequest({required String toFirebaseUid}) async {
    await _post('$_baseUrl/friends/request', {'toFirebaseUid': toFirebaseUid});
  }

  Future<List<dynamic>> getFriendRequests() async {
    final response = await _get('$_baseUrl/friends/requests');
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['requests'] ?? [];
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _post('$_baseUrl/friends/requests/$requestId/accept', {});
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _post('$_baseUrl/friends/requests/$requestId/reject', {});
  }

  Future<void> removeFriend(int friendId) async {
    await _delete('$_baseUrl/friends/$friendId');
  }

  // Invitations
  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) async {
    final response = await _post('$_baseUrl/invitations', {
      'groupId': groupId,
      'expiresInSeconds': expiresInSeconds,
    });
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptInvitation({required String token}) async {
    final response = await _post('$_baseUrl/invitations/accept', {
      'token': token,
    });
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  // Trends
  Future<List<dynamic>> getTrendingProducts({
    String? category,
    String timeframe = 'daily',
    int limit = 20,
  }) async {
    final queryParams = <String>[];
    if (category != null) queryParams.add('category=$category');
    queryParams.add('timeframe=$timeframe');
    queryParams.add('limit=$limit');
    final path = '$_baseUrl/trends/?${queryParams.join("&")}';
    final response = await _get(path);
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['trends'] ?? [];
  }

  Future<List<dynamic>> getTrendPredictions({
    String? category,
    int limit = 10,
  }) async {
    final queryParams = <String>[];
    if (category != null) queryParams.add('category=$category');
    queryParams.add('limit=$limit');
    final path = '$_baseUrl/trends/predictions?${queryParams.join("&")}';
    final response = await _get(path);
    final body = _decodeResponse(response) as Map<String, dynamic>;
    return body['predictions'] ?? [];
  }

  Future<void> trackProductView(String productId) async {
    final response = await _post('$_baseUrl/trends/track-view', {
      'product_id': productId,
    });
    _handleHttpResponse(response);
  }

  Future<Map<String, dynamic>> aggregateTrends({
    String timeframe = 'daily',
  }) async {
    final response = await _get(
      '$_baseUrl/trends/aggregate?timeframe=$timeframe',
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }
}
