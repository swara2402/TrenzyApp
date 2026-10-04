import 'api_client.dart';

class NotificationApi {
  NotificationApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getNotifications() async {
    final data = await _client.get(
      '/notifications',
      cacheTtl: const Duration(seconds: 15),
      cacheKey: 'notifications',
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.post('/notifications/read', body: {
      'notificationId': notificationId,
    });
    _client.invalidateCache('notifications');
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/notifications/read-all');
    _client.invalidateCache('notifications');
  }

  Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    final data = await _client.get('/notifications/unread-count');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> registerPushToken(String token, {String platform = 'fcm'}) async {
    await _client.post('/notifications/push/register', body: {
      'token': token,
      'platform': platform,
    });
  }
}
