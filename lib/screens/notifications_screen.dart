import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/notification_item.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';

final _notificationsProvider = FutureProvider<List<NotificationItem>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getNotifications();
  final raw = data['notifications'] as List<dynamic>? ?? [];
  return raw
      .whereType<Map>()
      .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.refresh_rounded,
              onLeadingPressed: () => context.pop(),
              onTrailingPressed: () => ref.invalidate(_notificationsProvider),
              onToggleTheme: onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auth == null
                        ? 'Sign in to see your notifications.'
                        : 'Stay up to date with your orders and blend activity.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (auth == null)
                    const FriendlyEmptyState(
                      title: 'Sign in to view notifications',
                      message:
                          'Your order updates and blend invites will appear here after signing in.',
                      icon: Icons.notifications_off_outlined,
                    )
                  else
                    Consumer(
                      builder: (context, ref2, _) {
                        final async = ref2.watch(_notificationsProvider);
                        return async.when(
                          loading: () => const _NotificationsSkeleton(),
                          error: (e, _) => AsyncRetryErrorState(
                            title: 'Failed to load notifications',
                            message: friendlyErrorMessage(e),
                            onRetry: () =>
                                ref2.invalidate(_notificationsProvider),
                          ),
                          data: (list) {
                            if (list.isEmpty) {
                              return const FriendlyEmptyState(
                                title: 'No notifications yet',
                                message:
                                    'Messages and blend events will appear here.',
                                icon: Icons.notifications_none_rounded,
                              );
                            }

                            return Column(
                              children: [
                                for (final n in list) ...[
                                  const SizedBox(height: 12),
                                  _NotificationTile(notification: n),
                                ],
                                const SizedBox(height: 6),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LoadingSkeletonShimmer(height: 80, radius: 22),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: notification.read
          ? null
          : () async {
              final api = ref.read(apiServiceProvider);
              await api.markNotificationRead(notification.id);
              if (!context.mounted) return;
              ref.invalidate(_notificationsProvider);
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read
              ? theme.colorScheme.surface
              : theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: notification.read
                ? theme.colorScheme.outline.withValues(alpha: 0.2)
                : theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                notification.read
                    ? Icons.notifications_rounded
                    : Icons.notifications_active_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: notification.read
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
