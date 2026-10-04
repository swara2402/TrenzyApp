import '../../models/friend.dart';
import 'api_client.dart';

class SocialApi {
  SocialApi(this._client);
  final ApiClient _client;

  // ---------- Friends ----------
  Future<List<Friend>> getFriends() async {
    final data = await _client.get('/friends');
    if (data is List) {
      return data.map((e) => Friend.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map<String, dynamic> && data['friends'] is List) {
      return (data['friends'] as List)
          .map((e) => Friend.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> sendFriendRequest({required String toFirebaseUid}) async {
    await _client.post('/friends/request', body: {'toFirebaseUid': toFirebaseUid});
  }

  Future<List<dynamic>> getFriendRequests({String box = 'incoming'}) async {
    final data = await _client.get('/friends/requests', queryParams: {'box': box});
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['requests'] is List) {
      return data['requests'] as List<dynamic>;
    }
    return [];
  }

  Future<void> acceptFriendRequest(int requestId) async {
    await _client.post('/friends/requests/$requestId/accept');
  }

  Future<void> rejectFriendRequest(int requestId) async {
    await _client.post('/friends/requests/$requestId/reject');
  }

  Future<void> removeFriend(int friendId) async {
    await _client.delete('/friends/$friendId');
  }

  Future<List<FriendSuggestion>> getFriendSuggestions() async {
    final data = await _client.get('/friends/suggestions');
    if (data is List) {
      return data.map((e) => FriendSuggestion.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map<String, dynamic> && data['suggestions'] is List) {
      return (data['suggestions'] as List)
          .map((e) => FriendSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ---------- Safety / Reports ----------
  Future<void> reportUser({
    required String targetFirebaseUid,
    required String reason,
    String? details,
  }) async {
    final body = <String, dynamic>{
      'target_type': 'user',
      'target_id': targetFirebaseUid,
      'reason': reason,
    };
    if (details != null && details.trim().isNotEmpty) body['details'] = details.trim();
    await _client.post('/moderation/reports', body: body);
  }

  // ---------- Follow ----------
  Future<void> followUser(String targetFirebaseUid) async {
    await _client.post('/follow', body: {'target_firebase_uid': targetFirebaseUid});
  }

  Future<void> unfollowUser(String targetFirebaseUid) async {
    await _client.delete('/follow/$targetFirebaseUid');
  }

  Future<bool> getFollowStatus(String targetFirebaseUid) async {
    final data = await _client.get('/follow/status', queryParams: {'target': targetFirebaseUid});
    if (data is Map<String, dynamic>) {
      return data['is_following'] == true || data['isFollowing'] == true;
    }
    return false;
  }

  Future<Map<String, dynamic>> getFollowers() async {
    final data = await _client.get('/follow/followers');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getFollowing() async {
    final data = await _client.get('/follow/following');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Posts ----------
  Future<Map<String, dynamic>> createPost({
    required String content,
    String? attachment,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (attachment != null) body['attachment'] = attachment;
    final data = await _client.post('/posts', body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getUserPosts({
    String? userId,
    int offset = 0,
    int limit = 20,
  }) async {
    final qp = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (userId != null) qp['user_id'] = userId;
    final data = await _client.get('/posts', queryParams: qp);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> deletePost(int postId) async {
    await _client.delete('/posts/$postId');
  }

  Future<void> likePost(int postId) async {
    await _client.post('/posts/$postId/like');
  }

  Future<void> unlikePost(int postId) async {
    await _client.delete('/posts/$postId/like');
  }

  Future<Map<String, dynamic>> commentOnPost(int postId, String content) async {
    final data = await _client.post('/posts/$postId/comments', body: {'content': content});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getComments(int postId) async {
    final data = await _client.get('/posts/$postId/comments');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Feed ----------
  Future<Map<String, dynamic>> getFeed({int offset = 0, int limit = 20}) async {
    final data = await _client.get('/feed', queryParams: {
      'offset': offset.toString(),
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Group Messages ----------
  Future<Map<String, dynamic>> getGroupMessages({
    required String groupId,
    int limit = 50,
  }) async {
    final data = await _client.get('/blends/$groupId/messages', queryParams: {
      'limit': limit.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
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
    };
    if (attachedProductId != null) body['attachedProductId'] = attachedProductId;
    if (attachedProductTitle != null) body['attachedProductTitle'] = attachedProductTitle;
    if (attachedProductImage != null) body['attachedProductImage'] = attachedProductImage;
    if (attachedProductPrice != null) body['attachedProductPrice'] = attachedProductPrice;

    await _client.post('/blends/messages/send', body: body);
  }
 
  // ---------- Direct Friend Chat ----------
  Future<Map<String, dynamic>> getDirectMessages({
    required String friendFirebaseUid,
    int limit = 50,
    int? beforeId,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (beforeId != null) query['before_id'] = beforeId.toString();
    final data = await _client.get(
      '/chat/conversations/${Uri.encodeComponent(friendFirebaseUid)}/messages',
      queryParams: query,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendDirectMessage({
    required String toFirebaseUid,
    required String message,
  }) async {
    final data = await _client.post(
      '/chat/messages',
      body: {
        'toFirebaseUid': toFirebaseUid,
        'message': message,
      },
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ---------- Activity ----------
  Future<Map<String, dynamic>> getActivity({int limit = 20, int offset = 0}) async {
    final data = await _client.get('/activity', queryParams: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> createActivity({
    required String kind,
    required String description,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? metadataJson,
  }) async {
    final body = <String, dynamic>{
      'kind': kind,
      'description': description,
    };
    if (targetId != null) body['target_id'] = targetId;
    if (targetType != null) body['target_type'] = targetType;
    if (metadataJson != null) body['metadata_json'] = metadataJson;

    await _client.post('/activity', body: body);
  }
}
