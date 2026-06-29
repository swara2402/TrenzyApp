import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../widgets/app_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final userName = userAsync.value?.name ?? 'Your Profile';
    final userEmail = userAsync.value?.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        AppTopBar(onToggleTheme: onToggleTheme),
        if (userAsync.value != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
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
                            child: Icon(
                              Icons.person,
                              size: 56,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (userAsync.value != null)
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
                      const SizedBox(height: 16),
                      if (userAsync.value == null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.push(AppRoutes.login),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Sign In'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
