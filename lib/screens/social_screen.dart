import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import '../providers/feed_provider.dart';
import '../theme/glass_theme.dart';

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(socialFeedProvider);
    final c = context.trenzyColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Activity',
          style: GlassTypography.display(
            fontSize: 20,
            color: c.foreground,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: feedAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: c.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: c.mutedFg, size: 48),
              const SizedBox(height: 16),
              Text('Could not load activity', style: TextStyle(color: c.mutedFg)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(socialFeedProvider),
                child: Text('Retry', style: TextStyle(color: c.primary)),
              ),
            ],
          ),
        ),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      color: c.mutedFg.withValues(alpha: 0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    DisplayText('No Activity Yet', fontSize: 20, weight: FontWeight.w600),
                    const SizedBox(height: 8),
                    Text(
                      'Follow creators and friends to see their fashion activity here.',
                      style: GlassTypography.body(color: c.mutedFg),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(socialFeedProvider),
            color: c.primary,
            backgroundColor: c.graphite,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityCard(context, activity);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, SocialActivity activity) {
    final c = context.trenzyColors;
    final isLike = activity.kind == 'like';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.graphite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isLike ? c.crimson : c.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLike ? Icons.favorite_rounded : Icons.swap_horiz_rounded,
                color: isLike ? c.crimson : c.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                activity.description,
                style: GlassTypography.body(color: c.foreground, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
