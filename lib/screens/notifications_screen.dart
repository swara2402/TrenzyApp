import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import '../providers/api_service_provider.dart';
import '../providers/notifications_provider.dart';
import '../theme/glass_theme.dart';
import 'package:go_router/go_router.dart';

String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays > 7) return '${diff.inDays ~/ 7}w';
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m';
  return 'now';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.foreground),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: context.trenzyColors.primary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: context.trenzyColors.mutedFg),
            tooltip: 'Mark all read',
            onPressed: () async {
              final api = ref.read(apiServiceProvider);
              await api.markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.trenzyColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 72,
                  color: context.trenzyColors.mutedFg.withValues(alpha: 0.4),
                ),
                SizedBox(height: 20),
                Text(
                  'Could not load notifications',
                  style: TextStyle(
                    color: context.trenzyColors.foreground.withValues(alpha: 0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 72,
                      color: context.trenzyColors.mutedFg.withValues(alpha: 0.4),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: context.trenzyColors.foreground.withValues(alpha: 0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When you get notifications, they\'ll show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.trenzyColors.mutedFg.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.15),
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () async {
                    if (n.read != true) {
                      final api = ref.read(apiServiceProvider);
                      await api.markNotificationRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationItem notification;
  final VoidCallback onTap;

  IconData _iconForKind(String? kind) {
    switch (kind) {
      case 'message':
        return Icons.message_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'vote':
        return Icons.thumb_up_rounded;
      case 'invite':
        return Icons.person_add_rounded;
      case 'blend':
        return Icons.groups_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.read
            ? context.trenzyColors.mutedFg.withValues(alpha: 0.15)
            : context.trenzyColors.primary.withValues(alpha: 0.2),
        child: Icon(
          _iconForKind(notification.kind),
          color: notification.read
              ? context.trenzyColors.mutedFg
              : context.trenzyColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          color: notification.read
              ? context.trenzyColors.mutedFg.withValues(alpha: 0.7)
              : context.trenzyColors.foreground,
          fontWeight: notification.read ? FontWeight.normal : FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.trenzyColors.mutedFg.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: Text(
        _timeAgo(notification.createdAt),
        style: TextStyle(
          color: context.trenzyColors.mutedFg.withValues(alpha: 0.4),
          fontSize: 11,
        ),
      ),
      onTap: onTap,
    );
  }
}
