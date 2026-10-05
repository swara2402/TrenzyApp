import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/models/blend_model.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart' show AppRoutes;
import 'package:share_plus/share_plus.dart';

class BlendLobbyScreen extends ConsumerWidget {
  const BlendLobbyScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.trenzyColors.glass,
                  border: Border.all(color: context.trenzyColors.glassBorder),
                ),
                child: Icon(Icons.group_off, color: context.trenzyColors.mutedFg, size: 36),
              ),
              SizedBox(height: 20),
              DisplayText('No blend group selected', fontSize: 18, weight: FontWeight.w600),
              SizedBox(height: 16),
              GlowButton(
                label: 'Go to Blend Hub',
                width: 180,
                height: 46,
                onTap: () => context.go(AppRoutes.blendHub),
              ),
            ],
          ),
        ),
      );
    }

    final groupAsync = ref.watch(blendGroupProvider(groupId));

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(child: LoadingSkeletonShimmer(height: 200, radius: 20)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.trenzyColors.crimson, size: 48),
              SizedBox(height: 16),
              DisplayText('Could not load blend group', fontSize: 16),
              SizedBox(height: 8),
              Text(err.toString(), style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 12)),
              SizedBox(height: 16),
              GlowButton(label: 'Retry', width: 120, height: 40, onTap: () => ref.invalidate(blendGroupProvider(groupId))),
            ],
          ),
        ),
      ),
      data: (group) => _BlendLobbyContent(group: group, ref: ref),
    );
  }
}

class _BlendLobbyContent extends StatelessWidget {
  const _BlendLobbyContent({required this.group, required this.ref});

  final BlendGroup group;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: Stack(
        children: [
          _buildAtmosphericBackground(),
          CustomScrollView(
            slivers: [
              // ── Glass app bar ─────────────────────────────────────────
              SliverAppBar(
                backgroundColor: context.trenzyColors.background.withValues(alpha: 0.6),
                pinned: true,
                elevation: 0,
                leading: GlassBackButton(
                  onTap: () => context.go(AppRoutes.blendHub),
                ),
                title: Text.rich(
                  TextSpan(
                    text: 'Blend: ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.trenzyColors.foreground),
                    children: [
                      TextSpan(
                        text: group.name,
                        style: TextStyle(color: context.trenzyColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.trenzyColors.glass,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.trenzyColors.glassBorder),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.dashboard_rounded, color: context.trenzyColors.primary, size: 18),
                      onPressed: () => context.go('${AppRoutes.blendDashboard}?groupId=${group.id}'),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      SizedBox(height: 28),
                      _buildParticipantGrid(),
                      SizedBox(height: 80),
                      _buildContextMessage(context),
                      SizedBox(height: 160),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildAtmosphericBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-1.5, -0.8),
          radius: 1.0,
          colors: [GlassColors.primary, GlassColors.background],
          stops: [0.0, 0.4],
        ),
      ),
    );
  }

  Widget _buildParticipantGrid() {
    final members = group.members;
    if (members.isEmpty) {
      return Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassColors.glass,
                border: Border.all(color: GlassColors.glassBorder),
              ),
              child: Icon(Icons.person_add_outlined, color: GlassColors.primary, size: 28),
            ),
            SizedBox(height: 12),
            Text(
              'No members yet. Share the invite code to add people.',
              style: GlassTypography.body(color: GlassColors.mutedFg, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 16,
      children: members.map((member) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              // Participant circle with presence indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Border color based on presence status
                      gradient: LinearGradient(
                        colors: member.isOnline == true
                            ? [GlassColors.emerald, GlassColors.emerald.withValues(alpha: 0.7)]
                            : [GlassColors.mutedFg, GlassColors.mutedFg.withValues(alpha: 0.5)],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GlassColors.graphite,
                      ),
                      child: Center(
                        child: Text(
                          member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: member.isOnline == true ? GlassColors.emerald : GlassColors.mutedFg,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Online presence dot
                  if (member.isOnline == true)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GlassColors.emerald,
                          border: Border.all(color: GlassColors.background, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: GlassColors.emerald.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Ready status indicator
                  if (member.isReady == true)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GlassColors.primary,
                          border: Border.all(color: GlassColors.background, width: 3),
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                member.userName,
                style: TextStyle(color: GlassColors.foreground, fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContextMessage(BuildContext context) {
    final members = group.members;
    final readyCount = members.where((m) => m.isReady == true).length;
    final notReadyMembers = members.where((m) => m.isReady != true).map((m) => m.userName).toList();
    final allReady = members.isNotEmpty && members.every((m) => m.isReady == true);
    
    final statusText = allReady
        ? 'Everyone ready \u2014 Start swiping to discover your shared style picks!'
        : (notReadyMembers.isNotEmpty
            ? 'Waiting for ${notReadyMembers.join(', ')}'
            : 'Invite friends to join this blend code!');

    return Column(
      children: [
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: allReady ? GlassColors.emerald : GlassColors.mutedFg,
            height: 1.6,
          ),
        ),
        SizedBox(height: 16),
        // Invite code: tap to copy, share button alongside
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied to clipboard')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: GlassColors.glass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GlassColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy_rounded, size: 16, color: GlassColors.primary),
                    SizedBox(width: 8),
                    Text(
                      group.inviteCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GlassColors.primary,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: () => _shareInvite(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: GlassGradients.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: GlassColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, size: 16, color: GlassColors.primaryFg),
                    SizedBox(width: 8),
                    Text(
                      'Share invite',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GlassColors.primaryFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: allReady ? GlassColors.emerald : GlassColors.mutedFg,
                boxShadow: allReady ? [
                  BoxShadow(
                    color: GlassColors.emerald.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ] : null,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '$readyCount / ${group.memberCount} Ready',
              style: TextStyle(
                fontSize: 12,
                color: allReady ? GlassColors.emerald : GlassColors.mutedFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (group.members.length < 2) ...[
          SizedBox(height: 20),
          _buildInviteCta(context),
        ],
      ],
    );
  }

  Future<void> _shareInvite(BuildContext context) async {
    final subject = 'Join my Blend on Trenzy';
    final text =
        'Join my Blend "${group.name}" with invite code ${group.inviteCode} '
        'and let\u2019s decide what to buy together. Download Trenzy to start swiping!';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the share sheet.')),
        );
      }
    }
  }

  Widget _buildInviteCta(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlassColors.primary.withValues(alpha: 0.14),
            GlassColors.emerald.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add_rounded, size: 20, color: GlassColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Blends are better with a friend',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GlassColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Invite someone so you can both swipe and agree on what to buy together.',
            style: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg, height: 1.4),
            textAlign: TextAlign.left,
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlowButton(
                  label: 'Invite a friend',
                  icon: Icons.person_add_alt_1_rounded,
                  height: 44,
                  onTap: () => _shareInvite(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final members = group.members;
    final notReadyMembers = members.where((m) => m.isReady != true).map((m) => m.userName).toList();
    final allReady = members.isNotEmpty && members.every((m) => m.isReady == true);
    return Positioned(
      bottom: 32,
      left: 20,
      right: 20,
      child: Column(
        children: [
          if (!allReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                notReadyMembers.isNotEmpty
                    ? 'Waiting for ${notReadyMembers.first}'
                    : 'Wait for all members to be ready',
                style: TextStyle(
                  color: GlassColors.mutedFg,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          GlowButton(
            label: allReady ? 'Everyone ready — Start' : 'Start Session',
            icon: Icons.bolt_rounded,
            height: 56,
            enabled: allReady,
            onTap: allReady ? () => context.go('${AppRoutes.blendSwipe}?groupId=${group.id}') : null,
          ),
        ],
      ),
    );
  }
}