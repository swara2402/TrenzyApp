import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/models/user_model.dart';
import 'package:trenzy/theme/glass_theme.dart';

class AllCreatorsScreen extends ConsumerWidget {
  const AllCreatorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorsAsync = ref.watch(discoverTrendingCreatorsProvider);

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
          'Style Creators',
          style: TextStyle(
            color: context.trenzyColors.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.trenzyColors.mutedFg),
            onPressed: () => ref.invalidate(discoverTrendingCreatorsProvider),
          ),
        ],
      ),
      body: creatorsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.trenzyColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, color: context.trenzyColors.mutedFg, size: 48),
              SizedBox(height: 16),
              Text(
                'Could not load creators',
                style: GlassTypography.body(color: context.trenzyColors.mutedFg),
              ),
              SizedBox(height: 12),
              GlowButton(
                label: 'Retry',
                width: 100,
                height: 36,
                onTap: () => ref.invalidate(discoverTrendingCreatorsProvider),
              ),
            ],
          ),
        ),
        data: (creators) {
          if (creators.isEmpty) {
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
                    child: Icon(Icons.people_outline, size: 36, color: context.trenzyColors.primary),
                  ),
                  SizedBox(height: 20),
                  DisplayText('No creators yet', fontSize: 18, weight: FontWeight.w600),
                  SizedBox(height: 8),
                  Text(
                    'Style creators will appear here as the community grows.',
                    style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(discoverTrendingCreatorsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: creators.length,
              separatorBuilder: (_, _) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                final creator = creators[index];
                return _CreatorTile(creator: creator);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CreatorTile extends StatelessWidget {
  final UserModel creator;

  const _CreatorTile({required this.creator});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      color: context.trenzyColors.graphite,
      radius: 16,
      margin: const EdgeInsets.only(bottom: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(
            AppRoutes.userProfile,
            extra: creator.id,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with gradient ring
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [context.trenzyColors.primary, context.trenzyColors.emerald],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: context.trenzyColors.graphite,
                    backgroundImage: NetworkImage(creator.avatarUrl),
                    child: null,
                  ),
                ),
                SizedBox(width: 14),
                // Name + handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.name,
                        style: TextStyle(
                          color: context.trenzyColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '@${creator.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
                        style: TextStyle(
                          color: context.trenzyColors.mutedFg,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Follow button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.trenzyColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'View',
                    style: TextStyle(
                      color: context.trenzyColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
