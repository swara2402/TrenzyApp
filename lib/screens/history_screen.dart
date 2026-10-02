import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:go_router/go_router.dart';

final activityFeedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final data = await api.getActivity(limit: 50);
  return List<Map<String, dynamic>>.from(data['activities'] ?? []);
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(activityFeedProvider);

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
          'History',
          style: TextStyle(
            color: context.trenzyColors.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.trenzyColors.mutedFg),
            onPressed: () => ref.invalidate(activityFeedProvider),
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.trenzyColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, color: context.trenzyColors.mutedFg, size: 48),
              SizedBox(height: 16),
              Text(
                'Could not load history',
                style: GlassTypography.body(color: context.trenzyColors.mutedFg),
              ),
              SizedBox(height: 12),
              GlowButton(
                label: 'Retry',
                width: 100,
                height: 36,
                onTap: () => ref.invalidate(activityFeedProvider),
              ),
            ],
          ),
        ),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.trenzyColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.history, size: 36, color: context.trenzyColors.primary),
                  ),
                  SizedBox(height: 20),
                  DisplayText('No activity yet', fontSize: 18, weight: FontWeight.w600),
                  SizedBox(height: 8),
                  Text(
                    'Your browsing history and actions will appear here.',
                    style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activityFeedProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: activities.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: context.trenzyColors.fg10,
                indent: 52,
              ),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _ActivityTile(activity: activity);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ActivityTile({required this.activity});

  IconData _iconForKind(String? kind) {
    switch (kind) {
      case 'like':
        return Icons.favorite_rounded;
      case 'view':
        return Icons.visibility_rounded;
      case 'save':
        return Icons.bookmark_rounded;
      case 'purchase':
        return Icons.shopping_bag_rounded;
      case 'blend':
        return Icons.groups_rounded;
      case 'post':
        return Icons.article_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _colorForKind(String? kind) {
    switch (kind) {
      case 'like':
        return GlassColors.crimson;
      case 'view':
        return GlassColors.fg60;
      case 'save':
        return GlassColors.primary;
      case 'purchase':
        return GlassColors.emerald;
      default:
        return GlassColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = activity['description'] as String? ?? '';
    final kind = activity['kind'] as String? ?? '';
    final createdAt = activity['created_at'] as String?;

    String timeText = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) {
          timeText = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeText = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeText = '${diff.inMinutes}m ago';
        } else {
          timeText = 'just now';
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colorForKind(kind).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForKind(kind),
              color: _colorForKind(kind),
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: context.trenzyColors.foreground,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (timeText.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      color: context.trenzyColors.fg40,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
