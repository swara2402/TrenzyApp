import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/analytics_service_provider.dart';
import '../providers/api_service_provider.dart';
import '../providers/auth_provider.dart' hide apiServiceProvider;
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';

class BlendHubScreen extends ConsumerWidget {
  const BlendHubScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  static const _recentComparisons = [
    _Comparison(
      name: 'You & Rohan',
      time: '2h ago',
      match: 88,
      avatarColorA: Color(0xFF8D6E63),
      avatarColorB: Color(0xFFFFAB91),
    ),
    _Comparison(
      name: 'You & Ananya',
      time: '1d ago',
      match: 94,
      avatarColorA: Color(0xFF90A4AE),
      avatarColorB: Color(0xFFCE93D8),
    ),
    _Comparison(
      name: 'You & Kabir',
      time: '3d ago',
      match: 72,
      avatarColorA: Color(0xFF80CBC4),
      avatarColorB: Color(0xFFFFCC80),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            AppTopBar(title: 'COMPARE', onToggleTheme: onToggleTheme),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.xs,
                AppSpacing.containerMargin,
                AppSpacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero compare card.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: panelDecoration(
                      context,
                      radius: AppRadius.sheet,
                    ),
                    child: Column(
                      children: [
                        _AvatarCluster(user: user),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Compare your style with friends',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Swipe together, vote together, and pick the perfect look as a group.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TapScale(
                          onTap: user == null
                              ? () => context.push(AppRoutes.login)
                              : () => _showCreateDialog(context, ref),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: peachGradient(context),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primaryContainer.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Start Comparing',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF2D2D2D),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.02,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.compare_arrows_rounded,
                                  color: Color(0xFF2D2D2D),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Blend action cards.
                  _BlendActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Create a Blend',
                    subtitle:
                        'Start a new group and invite friends with a room code.',
                    onTap: user == null
                        ? () => context.push(AppRoutes.login)
                        : () => _showCreateDialog(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BlendActionCard(
                    icon: Icons.login_rounded,
                    title: 'Join a Blend',
                    subtitle:
                        'Enter an invite code to jump into an active blend.',
                    onTap: user == null
                        ? () => context.push(AppRoutes.login)
                        : () => _showJoinDialog(context, ref),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Recent comparisons.
                  SectionHeader(
                    title: 'Recent Comparisons',
                    action: 'View all',
                    onAction: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Full history coming soon.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._recentComparisons.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ComparisonCard(comparison: c),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Weekend Blend');
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Blend'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Blend name',
                hintText: 'Date night picks',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true || !context.mounted) {
      controller.dispose();
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final group = await api.createBlend(name: controller.text.trim());
      controller.dispose();
      final groupId = group['id']?.toString() ?? '';
      await ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'blend_created', parameters: {'group_id': groupId});
      if (!context.mounted) return;
      context.push(AppRoutes.blendLobby, extra: groupId);
    } catch (e) {
      controller.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    friendlyErrorMessage(e),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final joined = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Join Blend'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'blend-a1b2c3',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter invite code' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );

    if (joined != true || !context.mounted) {
      controller.dispose();
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.joinBlend(groupId: controller.text.trim());
      final groupId = controller.text.trim();
      controller.dispose();
      await ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'blend_joined', parameters: {'group_id': groupId});
      if (!context.mounted) return;
      context.push(AppRoutes.blendLobby, extra: groupId);
    } catch (e) {
      controller.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    friendlyErrorMessage(e),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _AvatarCluster extends StatelessWidget {
  const _AvatarCluster({this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(user?.name ?? 'You');

    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // User avatar.
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 96,
            child: _AvatarBubble(
              initials: initials,
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              ringColor: cs.primary.withValues(alpha: 0.25),
            ),
          ),
          // Friend avatar.
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 52,
            child: _AvatarBubble(
              initials: 'FR',
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurface,
              ringColor: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          // Add button.
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 8,
            child: TapScale(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite friends coming soon.')),
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: cs.primary, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return 'U';
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.initials,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.ringColor,
  });

  final String initials;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 2),
        ],
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: backgroundColor,
        child: Text(
          initials,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _BlendActionCard extends StatelessWidget {
  const _BlendActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: panelDecoration(context, radius: AppRadius.card),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Comparison {
  const _Comparison({
    required this.name,
    required this.time,
    required this.match,
    required this.avatarColorA,
    required this.avatarColorB,
  });

  final String name;
  final String time;
  final int match;
  final Color avatarColorA;
  final Color avatarColorB;
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final _Comparison comparison;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapScale(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comparison details coming soon.')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: panelDecoration(context, radius: AppRadius.card),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: comparison.avatarColorA,
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: comparison.avatarColorB,
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comparison.name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comparison.time,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${comparison.match}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
