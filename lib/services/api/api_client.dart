import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../environment_config.dart' show EnvConfig;
import '../../models/api_exception.dart';
import '../dev_auth.dart';
import '../feature_flags.dart';

void _log(String msg) {
  debugPrint('[API] $msg');
}

class CacheEntry {
  final dynamic data;
  final DateTime expiry;
  DateTime lastAccessed;
  CacheEntry(this.data, this.expiry) : lastAccessed = DateTime.now();
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class ApiClient {
  ApiClient({
    required this.firebaseAuth,
    http.Client? client,
  }) : _client = client;

  final FirebaseAuth firebaseAuth;
  final http.Client? _client;
  http.Client? _defaultClient;

  http.Client get client => _client ?? (_defaultClient ??= http.Client());

  static final Map<String, CacheEntry> _requestCache = <String, CacheEntry>{};
  static const int _maxCacheSize = 100;

  static String? _cachedToken;
  static DateTime? _tokenExpiry;
  static String? _cachedTokenUid;

  static void Function()? onSessionExpired;

  static const Duration timeout = Duration(seconds: 20);
  static const int maxRetries = 2;

  static String get baseUrl => '${EnvConfig.apiBaseUrl}/api';
  static String get socketBaseUrl => EnvConfig.socketBaseUrl;

  static String? resolveImageUrl(String? imageUrl) {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return raw;
    }

    final path = raw.replaceFirst(RegExp(r'^\./+'), '');
    final segments = path.split('/');
    final filename = segments.isNotEmpty ? segments.last : '';

    // Catalog product photos are hosted on Cloudflare Pages under /images.
    if (RegExp(r'^TRZ-\d+\.jpg$', caseSensitive: false)
        .hasMatch(filename)) {
      return 'https://e507cfa3.trenzy-images.pages.dev/images/$filename';
    }

    // Keep non-catalog uploads on the configured backend host.
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(EnvConfig.apiBaseUrl)
        .resolve(normalizedPath)
        .toString();
  }

  static void clearCache() {
    _requestCache.clear();
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedTokenUid = null;
  }

  void putCache(String key, dynamic data, Duration ttl) {
    if (_requestCache.length >= _maxCacheSize && !_requestCache.containsKey(key)) {
      String lruKey = _requestCache.keys.first;
      DateTime oldest = _requestCache[lruKey]!.lastAccessed;
      for (final e in _requestCache.entries) {
        if (e.value.lastAccessed.isBefore(oldest)) {
          oldest = e.value.lastAccessed;
          lruKey = e.key;
        }
      }
      _requestCache.remove(lruKey);
    }
    _requestCache[key] = CacheEntry(data, DateTime.now().add(ttl));
  }

  CacheEntry? getCache(String key) {
    final entry = _requestCache[key];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    return entry;
  }

  void invalidateCache(String prefix) {
    _requestCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (FeatureFlags.devAuthBypass) {
      return DevAuth.devToken();
    }
    final user = firebaseAuth.currentUser;
    if (user == null) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = null;
      return null;
    }

    if (_cachedTokenUid != user.uid) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = user.uid;
    }

    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    final token = await user.getIdToken(forceRefresh);
    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
    return token;
  }

  Future<String?> _refreshAfterUnauthorized() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) {
        throw ApiException(
          'Could not refresh the authentication session. Please retry.',
          statusCode: 503,
        );
      }
      return token;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidSessionCodes.contains(error.code)) {
        return null;
      }
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    } catch (error) {
      _log('Token refresh failed temporarily: $error');
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    }
  }

  Future<Map<String, String>> authHeaders({
    bool forceRefresh = false,
    Map<String, String>? extra,
  }) async {
    final token = await getIdToken(forceRefresh: forceRefresh);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  dynamic handleResponse(http.Response response, {String? endpoint}) {
    final body = response.body;
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        decoded = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      message = decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          message;
    }

    _log('Error $endpoint [${response.statusCode}]: $message');

    throw ApiException(
      message,
      statusCode: response.statusCode,
      details: decoded is Map<String, dynamic> ? decoded : endpoint,
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheTtl,
    String? cacheKey,
  }) async {
    final key = cacheKey ?? endpoint;
    if (cacheTtl != null) {
      final cached = getCache(key);
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final headers = await authHeaders();
        final response = await client.get(uri, headers: headers).timeout(timeout);
        final result = handleResponse(response, endpoint: endpoint);
        if (cacheTtl != null) {
          putCache(key, result, cacheTtl);
        }
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        if (attempts >= maxRetries) {
          throw ApiException('Connection failed: $e', details: endpoint);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> _sendWithRetry(
    String endpoint,
    Future<http.Response> Function() request, {
    bool refreshOn401 = true,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final response = await request();
        final result = handleResponse(response, endpoint: endpoint);
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && refreshOn401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        throw ApiException('Connection failed: $e', details: endpoint);
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders(extra: extraHeaders);
      return client.post(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.put(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.patch(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.delete(uri, headers: headers).timeout(timeout);
    });
  }

  Future<dynamic> uploadMultipart(
    String endpoint,
    XFile file, {
    String fieldName = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _sendWithRetry(endpoint, () async {
      final token = await getIdToken(forceRefresh: false);
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      return http.Response.fromStream(streamedResponse);
    });
  }
}, caseSensitive: false).hasMatch(filename)) {
      return 'https://e507cfa3.trenzy-images.pages.dev/images/$filename';
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(EnvConfig.apiBaseUrl).resolve(normalizedPath).toString();
  }

  static void clearCache() {
    _requestCache.clear();
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedTokenUid = null;
  }

  void putCache(String key, dynamic data, Duration ttl) {
    if (_requestCache.length >= _maxCacheSize && !_requestCache.containsKey(key)) {
      String lruKey = _requestCache.keys.first;
      DateTime oldest = _requestCache[lruKey]!.lastAccessed;
      for (final e in _requestCache.entries) {
        if (e.value.lastAccessed.isBefore(oldest)) {
          oldest = e.value.lastAccessed;
          lruKey = e.key;
        }
      }
      _requestCache.remove(lruKey);
    }
    _requestCache[key] = CacheEntry(data, DateTime.now().add(ttl));
  }

  CacheEntry? getCache(String key) {
    final entry = _requestCache[key];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    return entry;
  }

  void invalidateCache(String prefix) {
    _requestCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (FeatureFlags.devAuthBypass) {
      return DevAuth.devToken();
    }
    final user = firebaseAuth.currentUser;
    if (user == null) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = null;
      return null;
    }

    if (_cachedTokenUid != user.uid) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = user.uid;
    }

    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    final token = await user.getIdToken(forceRefresh);
    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
    return token;
  }

  Future<String?> _refreshAfterUnauthorized() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) {
        throw ApiException(
          'Could not refresh the authentication session. Please retry.',
          statusCode: 503,
        );
      }
      return token;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidSessionCodes.contains(error.code)) {
        return null;
      }
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    } catch (error) {
      _log('Token refresh failed temporarily: $error');
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    }
  }

  Future<Map<String, String>> authHeaders({
    bool forceRefresh = false,
    Map<String, String>? extra,
  }) async {
    final token = await getIdToken(forceRefresh: forceRefresh);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  dynamic handleResponse(http.Response response, {String? endpoint}) {
    final body = response.body;
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        decoded = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      message = decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          message;
    }

    _log('Error $endpoint [${response.statusCode}]: $message');

    throw ApiException(
      message,
      statusCode: response.statusCode,
      details: decoded is Map<String, dynamic> ? decoded : endpoint,
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheTtl,
    String? cacheKey,
  }) async {
    final key = cacheKey ?? endpoint;
    if (cacheTtl != null) {
      final cached = getCache(key);
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final headers = await authHeaders();
        final response = await client.get(uri, headers: headers).timeout(timeout);
        final result = handleResponse(response, endpoint: endpoint);
        if (cacheTtl != null) {
          putCache(key, result, cacheTtl);
        }
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        if (attempts >= maxRetries) {
          throw ApiException('Connection failed: $e', details: endpoint);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> _sendWithRetry(
    String endpoint,
    Future<http.Response> Function() request, {
    bool refreshOn401 = true,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final response = await request();
        final result = handleResponse(response, endpoint: endpoint);
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && refreshOn401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        throw ApiException('Connection failed: $e', details: endpoint);
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders(extra: extraHeaders);
      return client.post(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.put(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.patch(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.delete(uri, headers: headers).timeout(timeout);
    });
  }

  Future<dynamic> uploadMultipart(
    String endpoint,
    XFile file, {
    String fieldName = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _sendWithRetry(endpoint, () async {
      final token = await getIdToken(forceRefresh: false);
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      return http.Response.fromStream(streamedResponse);
    });
  }
}, caseSensitive: false)
        .hasMatch(filename)) {
      return 'https://e507cfa3.trenzy-images.pages.dev/images/$filename';
    }

    // Keep non-catalog uploads on the configured backend host.
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(EnvConfig.apiBaseUrl)
        .resolve(normalizedPath)
        .toString();
  }

  static void clearCache() {
    _requestCache.clear();
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedTokenUid = null;
  }

  void putCache(String key, dynamic data, Duration ttl) {
    if (_requestCache.length >= _maxCacheSize && !_requestCache.containsKey(key)) {
      String lruKey = _requestCache.keys.first;
      DateTime oldest = _requestCache[lruKey]!.lastAccessed;
      for (final e in _requestCache.entries) {
        if (e.value.lastAccessed.isBefore(oldest)) {
          oldest = e.value.lastAccessed;
          lruKey = e.key;
        }
      }
      _requestCache.remove(lruKey);
    }
    _requestCache[key] = CacheEntry(data, DateTime.now().add(ttl));
  }

  CacheEntry? getCache(String key) {
    final entry = _requestCache[key];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    return entry;
  }

  void invalidateCache(String prefix) {
    _requestCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (FeatureFlags.devAuthBypass) {
      return DevAuth.devToken();
    }
    final user = firebaseAuth.currentUser;
    if (user == null) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = null;
      return null;
    }

    if (_cachedTokenUid != user.uid) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = user.uid;
    }

    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    final token = await user.getIdToken(forceRefresh);
    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
    return token;
  }

  Future<String?> _refreshAfterUnauthorized() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) {
        throw ApiException(
          'Could not refresh the authentication session. Please retry.',
          statusCode: 503,
        );
      }
      return token;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidSessionCodes.contains(error.code)) {
        return null;
      }
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    } catch (error) {
      _log('Token refresh failed temporarily: $error');
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    }
  }

  Future<Map<String, String>> authHeaders({
    bool forceRefresh = false,
    Map<String, String>? extra,
  }) async {
    final token = await getIdToken(forceRefresh: forceRefresh);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  dynamic handleResponse(http.Response response, {String? endpoint}) {
    final body = response.body;
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        decoded = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      message = decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          message;
    }

    _log('Error $endpoint [${response.statusCode}]: $message');

    throw ApiException(
      message,
      statusCode: response.statusCode,
      details: decoded is Map<String, dynamic> ? decoded : endpoint,
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheTtl,
    String? cacheKey,
  }) async {
    final key = cacheKey ?? endpoint;
    if (cacheTtl != null) {
      final cached = getCache(key);
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final headers = await authHeaders();
        final response = await client.get(uri, headers: headers).timeout(timeout);
        final result = handleResponse(response, endpoint: endpoint);
        if (cacheTtl != null) {
          putCache(key, result, cacheTtl);
        }
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        if (attempts >= maxRetries) {
          throw ApiException('Connection failed: $e', details: endpoint);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> _sendWithRetry(
    String endpoint,
    Future<http.Response> Function() request, {
    bool refreshOn401 = true,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final response = await request();
        final result = handleResponse(response, endpoint: endpoint);
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && refreshOn401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        throw ApiException('Connection failed: $e', details: endpoint);
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders(extra: extraHeaders);
      return client.post(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.put(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.patch(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.delete(uri, headers: headers).timeout(timeout);
    });
  }

  Future<dynamic> uploadMultipart(
    String endpoint,
    XFile file, {
    String fieldName = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _sendWithRetry(endpoint, () async {
      final token = await getIdToken(forceRefresh: false);
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      return http.Response.fromStream(streamedResponse);
    });
  }
}, caseSensitive: false).hasMatch(filename)) {
      return 'https://e507cfa3.trenzy-images.pages.dev/images/$filename';
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(EnvConfig.apiBaseUrl).resolve(normalizedPath).toString();
  }

  static void clearCache() {
    _requestCache.clear();
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedTokenUid = null;
  }

  void putCache(String key, dynamic data, Duration ttl) {
    if (_requestCache.length >= _maxCacheSize && !_requestCache.containsKey(key)) {
      String lruKey = _requestCache.keys.first;
      DateTime oldest = _requestCache[lruKey]!.lastAccessed;
      for (final e in _requestCache.entries) {
        if (e.value.lastAccessed.isBefore(oldest)) {
          oldest = e.value.lastAccessed;
          lruKey = e.key;
        }
      }
      _requestCache.remove(lruKey);
    }
    _requestCache[key] = CacheEntry(data, DateTime.now().add(ttl));
  }

  CacheEntry? getCache(String key) {
    final entry = _requestCache[key];
    if (entry == null) return null;
    entry.lastAccessed = DateTime.now();
    return entry;
  }

  void invalidateCache(String prefix) {
    _requestCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (FeatureFlags.devAuthBypass) {
      return DevAuth.devToken();
    }
    final user = firebaseAuth.currentUser;
    if (user == null) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = null;
      return null;
    }

    if (_cachedTokenUid != user.uid) {
      _cachedToken = null;
      _tokenExpiry = null;
      _cachedTokenUid = user.uid;
    }

    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    final token = await user.getIdToken(forceRefresh);
    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
    return token;
  }

  Future<String?> _refreshAfterUnauthorized() async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final token = await getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) {
        throw ApiException(
          'Could not refresh the authentication session. Please retry.',
          statusCode: 503,
        );
      }
      return token;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidSessionCodes.contains(error.code)) {
        return null;
      }
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    } catch (error) {
      _log('Token refresh failed temporarily: $error');
      throw ApiException(
        'Could not refresh the authentication session. Please retry.',
        statusCode: 503,
        details: error,
      );
    }
  }

  Future<Map<String, String>> authHeaders({
    bool forceRefresh = false,
    Map<String, String>? extra,
  }) async {
    final token = await getIdToken(forceRefresh: forceRefresh);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  dynamic handleResponse(http.Response response, {String? endpoint}) {
    final body = response.body;
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        decoded = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      message = decoded['detail']?.toString() ??
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          message;
    }

    _log('Error $endpoint [${response.statusCode}]: $message');

    throw ApiException(
      message,
      statusCode: response.statusCode,
      details: decoded is Map<String, dynamic> ? decoded : endpoint,
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheTtl,
    String? cacheKey,
  }) async {
    final key = cacheKey ?? endpoint;
    if (cacheTtl != null) {
      final cached = getCache(key);
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final headers = await authHeaders();
        final response = await client.get(uri, headers: headers).timeout(timeout);
        final result = handleResponse(response, endpoint: endpoint);
        if (cacheTtl != null) {
          putCache(key, result, cacheTtl);
        }
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        if (attempts >= maxRetries) {
          throw ApiException('Connection failed: $e', details: endpoint);
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> _sendWithRetry(
    String endpoint,
    Future<http.Response> Function() request, {
    bool refreshOn401 = true,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final response = await request();
        final result = handleResponse(response, endpoint: endpoint);
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 401 && refreshOn401 && attempts == 1) {
          final refreshed = await _refreshAfterUnauthorized();
          if (refreshed == null || refreshed.isEmpty) {
            onSessionExpired?.call();
            rethrow;
          }
          continue;
        }
        if (e.statusCode == 401) {
          onSessionExpired?.call();
        }
        rethrow;
      } catch (e) {
        throw ApiException('Connection failed: $e', details: endpoint);
      }
    }
    throw ApiException('Request failed after retries', details: endpoint);
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders(extra: extraHeaders);
      return client.post(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.put(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final jsonBody = body != null ? jsonEncode(body) : null;

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.patch(uri, headers: headers, body: jsonBody).timeout(timeout);
    });
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _sendWithRetry(endpoint, () async {
      final headers = await authHeaders();
      return client.delete(uri, headers: headers).timeout(timeout);
    });
  }

  Future<dynamic> uploadMultipart(
    String endpoint,
    XFile file, {
    String fieldName = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _sendWithRetry(endpoint, () async {
      final token = await getIdToken(forceRefresh: false);
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      return http.Response.fromStream(streamedResponse);
    });
  }
}