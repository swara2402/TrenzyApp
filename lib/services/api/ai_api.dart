import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class AiApi {
  AiApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getStyleDna() async {
    final data = await _client.get('/ai/style-dna');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> refreshStyleDna() async {
    final data = await _client.post('/ai/style-dna/refresh');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getModelHealth() async {
    final data = await _client.get('/ai/models/health');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getAiRecommendations({int limit = 20}) async {
    final data = await _client.post('/ai/recommendations', body: {'limit': limit});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> generateOutfits({
    required String prompt,
    int numOptions = 3,
    Map<String, dynamic>? context,
  }) async {
    final data = await _client.post('/ai/outfits/generate', body: {
      'prompt': prompt,
      'num_options': numOptions,
      if (context != null) 'context': context,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> stylistChat({
    required String message,
    int? conversationId,
  }) async {
    final data = await _client.post('/ai/stylist/chat', body: {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> stylistOutfit(String prompt) async {
    final data = await _client.post('/ai/stylist/outfit', body: {'prompt': prompt});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> visualSearch(XFile image, {int limit = 20}) async {
    final data = await _client.uploadMultipart('/ai/visual-search?limit=$limit', image, fieldName: 'image');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
