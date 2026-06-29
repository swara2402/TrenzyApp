import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

//import '../models/blend_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_stats_provider.dart';
import '../providers/blend_provider.dart';
import '../router/app_router.dart';

import '../widgets/app_widgets.dart';
import '../theme/app_spacing.dart';
import '../utils/error_utils.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(authProvider);
    final userName = userAsync.value?.name ?? 'Your Profile';
    final userEmail = userAsync.value?.email ?? '';
    final styleTag = isDark ? 'CYBER-MINIMALIST' : 'LUXE MINIMALIST';

    return CustomScrollView(
      slivers: [
        AppTopBar(
          leading: Icons.arrow_back_rounded,
          onLeadingPressed: () => context.go(AppRoutes.home),
          onToggleTheme: widget.onToggleTheme,
        ),
        if (userAsync.value != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  tooltip: 'Sign Out',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.2)
                        : Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.5),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                decoration: panelDecoration(context, radius: 28),
                child: Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: isDark
                                    ? [
                                        Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.18),
                                        Theme.of(context).colorScheme.surface,
                                      ]
                                    : [
                                        Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.10),
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                      ],
                              ),
                            ),
                            child: const Icon(Icons.person, size: 56),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.22),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          styleTag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      StyleIdentityCard(
                        identity: 'Curated Luxe Minimalist',
                        vibeLine:
                            'You gravitate toward polished silhouettes, soft neutrals, and elevated finishing details.',
                        traits: [
                          'Clean Layers',
                          'Soft Gold',
                          'Day-to-Night',
                          'Tailored Ease',
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your Style Stats',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              ref
                  .watch(userStatsProvider)
                  .when(
                    loading: () => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.28,
                      children: [
                        StatBox(
                          value: '--',
                          label: 'Decisions',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '--',
                          label: 'Friends',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '--%',
                          label: 'Match',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '--',
                          label: 'Aesthetic',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    error: (e, _) => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.28,
                      children: [
                        StatBox(
                          value: '—',
                          label: 'Decisions',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '—',
                          label: 'Friends',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '—',
                          label: 'Match',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '—',
                          label: 'Aesthetic',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    data: (stats) => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.28,
                      children: [
                        StatBox(
                          value: '${stats.decisionCount}',
                          label: 'Decisions',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: '${stats.friendsCount}',
                          label: 'Friends',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: stats.matchPercentage != null
                              ? '${stats.matchPercentage}%'
                              : '—',
                          label: 'Match',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        StatBox(
                          value: stats.styleAesthetic ?? '—',
                          label: 'Aesthetic',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 26),
              SectionHeader(
                title: 'Your Decisions',
                action: 'View Archive',
                onAction: () {
                  context.push(AppRoutes.history);
                },
              ),
              const SizedBox(height: 12),
              ref
                  .watch(userBlendGroupsProvider)
                  .when(
                    loading: () => const DecisionShowcaseLoading(),
                    error: (e, _) => const DecisionShowcaseFallback(),
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const DecisionShowcaseFallback();
                      }

                      return Column(
                        children: [
                          for (final group in groups.take(3)) ...[
                            DecisionHistoryCard(
                              group: group,
                              onTap: () => context.push(
                                '${AppRoutes.blendHub}/${group.id}',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
              const SizedBox(height: 26),
              Text(
                'Profile & Preferences',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              if (userAsync.value != null)
                SettingsTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit Profile',
                  onTap: () => _showEditProfileDialog(context, ref, userName),
                ),

              SettingsTile(
                icon: Icons.favorite_border_rounded,
                title: 'Wishlist',
                onTap: () => context.push(AppRoutes.wishlist),
              ),

              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: panelDecoration(context, radius: AppRadius.panel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferences',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Budget: Rs ${_budget.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: _budget,
                      min: 20,
                      max: 300,
                      divisions: 14,
                      onChanged: (v) {
                        setState(() {
                          _budget = v;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _categoryOptions)
                          ChoiceChip(
                            label: Text(option),
                            selected: _selectedCategories.contains(option),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(option);
                                } else {
                                  _selectedCategories.remove(option);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              SettingsTile(
                icon: Icons.feedback_rounded,
                title: 'Feedback',
                onTap: () => _showFeedbackDialog(context),
              ),

              const SizedBox(height: AppSpacing.lg),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ]),
          ),
        ),
      ],
    );
  }

  double _budget = 120;
  final List<String> _selectedCategories = [];

  final List<String> _categoryOptions = const [
    'Dresses',
    'Shoes',
    'Accessories',
    'Tops',
    'Bottoms',
  ];

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What can we improve?',
                hintText: 'Write your feedback here…',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Feedback can\'t be empty';
                }
                return null;
              },
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
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
    }

    controller.dispose();
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    // Avatar upload is UI-only for now (no image picker dependency in this project).

    // We still provide a preview slot and allow the user to submit without breaking flows.
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    final avatarCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Avatar'),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.person, size: 34),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL (optional)',
                    helperText:
                        'Paste an image URL to preview. Upload picker comes later.',
                  ),
                ),
              ],
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true || !context.mounted) {
      controller.dispose();
      return;
    }

    try {
      // Only update name today (backend/provider integration for avatar is not confirmed).
      await ref
          .read(authProvider.notifier)
          .updateProfile(name: controller.text.trim());

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
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
    } finally {
      controller.dispose();
      avatarCtrl.dispose();
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your wishlist and cart will be cleared locally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authProvider.notifier).logout();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have been signed out.'),
        duration: Duration(seconds: 2),
      ),
    );

    context.go(AppRoutes.login);
  }
}
