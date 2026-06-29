import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Welcome to Trenzy',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: onToggleTheme,
                          icon: const Icon(Icons.brightness_6_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Decide faster.\nCurate better.',

                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(height: 1.05, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We help you compare options and save outcomes for later.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _FeatureTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'AI-curated suggestions',
                      message:
                          'Tell us what you’re deciding, we suggest options.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.groups_rounded,
                      title: 'Live rooms & voting',
                      message:
                          'Friends react in real time so you reach a result.',
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.history_rounded,
                      title: 'Decision history',
                      message: 'Save your best outcomes and revisit anytime.',
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            context.go('${AppRoutes.login}?mode=signup'),
                        child: const Text('Get Started'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF0E6F5),
        ),
        color: Theme.of(context).cardColor,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.12,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
