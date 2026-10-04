import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/blend_provider.dart';
import '../models/blend_model.dart';
import '../theme/glass_theme.dart';
import '../router/app_router.dart';
import '../widgets/section_states.dart';

class BlendHubScreen extends ConsumerWidget {
  const BlendHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blendsAsync = ref.watch(userBlendGroupsProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userBlendGroupsProvider);
          },
          color: context.trenzyColors.primary,
          backgroundColor: context.trenzyColors.graphite,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLENDS',
                              style: TextStyle(
                                fontFamily: GlassTypography.bodyFont,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: context.trenzyColors.primary,
                              ),
                            ),
                            SizedBox(height: 4),
                            DisplayText(
                              'Your Active Blends',
                              fontSize: 24,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.trenzyColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.trenzyColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${blendsAsync.valueOrNull?.length ?? 0} Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.trenzyColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActiveBlends(context, ref, blendsAsync),
                  SizedBox(height: 48),
                  _buildActionTiles(context),
                  SizedBox(height: 56),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBlends(BuildContext context, WidgetRef ref, AsyncValue<List<BlendGroup>> blendsAsync) {
    return blendsAsync.when(
      loading: () => SizedBox(
        height: 380,
        child: Center(child: LoadingSkeletonShimmer(height: 380, radius: 20)),
      ),
      error: (err, _) => ErrorSection(
        title: 'Could not load blends',
        message: friendlyError(err),
        onRetry: () => ref.invalidate(userBlendGroupsProvider),
      ),
      data: (blends) {
        if (blends.isEmpty) {
          return EmptySection(
            title: 'Start a Blend with friends',
            subtitle: 'Swipe, vote, and decide what to buy together. Create a new blend or join one with an invite code.',
            icon: Icons.groups_outlined,
            actionLabel: 'Create New Blend',
            onAction: () => context.go(AppRoutes.createBlend),
          );
        }
        return SizedBox(
          height: 380,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: blends.length,
            itemBuilder: (context, index) {
              final blend = blends[index];
              return _BlendCard(
                match: '${blend.memberCount} Members',
                title: blend.name,
                updateTime: '#${blend.inviteCode}',
                onTap: () => context.go('${AppRoutes.blendLobby}?groupId=${blend.id}'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionTiles(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.add_circle,
            label: 'Create New',
            onTap: () => context.go(AppRoutes.createBlend),
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: _ActionTile(
            icon: Icons.qr_code_scanner,
            label: 'Join Invite',
            onTap: () => context.go(AppRoutes.joinBlend),
          ),
        ),
      ],
    );
  }
}

class _BlendCard extends StatelessWidget {
  final String match;
  final String title;
  final String updateTime;
  final VoidCallback? onTap;

  const _BlendCard({
    required this.match,
    required this.title,
    required this.updateTime,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: context.trenzyColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gradient accent bar at top
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.trenzyColors.primary, context.trenzyColors.emerald],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),
            SizedBox(height: 32),
            // Groups icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.primary.withValues(alpha: 0.12),
                border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.groups, color: context.trenzyColors.primary, size: 28),
            ),
            SizedBox(height: 20),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.trenzyColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 12),
            // Member count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: GlassGradients.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                match,
                style: TextStyle(
                  color: context.trenzyColors.primaryFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 10),
            // Invite code
            Text(
              updateTime,
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.trenzyColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: context.trenzyColors.primary, size: 32),
            ),
            SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: context.trenzyColors.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}