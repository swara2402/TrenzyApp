import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <NotificationItem>[];

  final api = ref.read(apiServiceProvider);
  final data = await api.getNotifications();
  final list = data['notifications'] as List<dynamic>? ?? [];
  return list
      .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return 0;

  final api = ref.read(apiServiceProvider);
  final data = await api.getUnreadNotificationCount();
  return (data['unreadCount'] as int?) ?? 0;
});
