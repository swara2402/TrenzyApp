import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../environment_config.dart' show EnvConfig;
import '../google_sign_in_service.dart';

class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.apiBaseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _client.handleResponse(response, endpoint: '/auth/login');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.apiBaseUrl}/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = _client.handleResponse(response, endpoint: '/auth/signup');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> googleLogin() async {
    final user = await GoogleSignInService.instance.signIn();
    final token = await user.getIdToken();
    return {
      'user': {
        'id': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'token': token ?? '',
      },
      'token': token,
    };
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final data = await _client.get(
      '/auth/me',
      cacheTtl: const Duration(minutes: 5),
      cacheKey: 'currentUser',
    );
    if (data is Map<String, dynamic>) {
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        return data['user'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }


  Future<void> resetPassword(String email) async {
    await _client.post('/auth/reset-password', body: {'email': email});
  }
}
