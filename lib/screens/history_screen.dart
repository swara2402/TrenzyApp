import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(authProvider);
    final apiService = ref.watch(apiServiceProvider);

    return userAsync.when(
      loading: () {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                AppTopBar(
                  leading: Icons.arrow_back_rounded,
                  trailing: Icons.history_rounded,
                  onLeadingPressed: () => context.pop(),
                  onToggleTheme: onToggleTheme,
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        );
      },
      error: (e, st) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                AppTopBar(
                  leading: Icons.arrow_back_rounded,
                  trailing: Icons.history_rounded,
                  onLeadingPressed: () => context.pop(),
                  onToggleTheme: onToggleTheme,
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load profile.\nPlease sign in again.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => context.push(AppRoutes.login),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Go to Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  AppTopBar(
                    leading: Icons.arrow_back_rounded,
                    trailing: Icons.history_rounded,
                    onLeadingPressed: () => context.pop(),
                    onToggleTheme: onToggleTheme,
                  ),
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Please sign in to view history.'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _HistoryBody(
          apiService: apiService,
          isDark: isDark,
          onToggleTheme: onToggleTheme,
          onLoginTap: () => context.push(AppRoutes.login),
        );
      },
    );
  }
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody({
    required this.apiService,
    required this.isDark,
    required this.onToggleTheme,
    required this.onLoginTap,
  });

  final ApiService apiService;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onLoginTap;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiService.getDecisions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.history_rounded,
              onLeadingPressed: () => context.pop(),
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Your Previous Results',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saved decisions are loaded from your account history.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<List<dynamic>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            FriendlyEmptyState(
                              title: 'Could not load history',
                              message: 'Sign in again or try later.',
                              icon: Icons.refresh_rounded,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: widget.onLoginTap,
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Sign in'),
                            ),
                          ],
                        );
                      }

                      final decisions = snapshot.data ?? const [];
                      if (decisions.isEmpty) {
                        return const FriendlyEmptyState(
                          title: 'No decisions saved yet',
                          message: 'Finalize a decision to see it here.',
                          icon: Icons.history_rounded,
                        );
                      }

                      return Column(
                        children: [
                          for (final decision in decisions) ...[
                            _DecisionHistoryCard(decision: decision),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionHistoryCard extends StatelessWidget {
  const _DecisionHistoryCard({required this.decision});

  final dynamic decision;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> map = decision is Map<String, dynamic>
        ? decision
        : {};

    final query = map['query']?.toString() ?? '';
    final recommendedOptionId = map['recommendedOptionId']?.toString() ?? '';
    final reasoning = map['reasoning']?.toString() ?? '';
    final socialApproval = (map['socialApproval'] is num)
        ? (map['socialApproval'] as num).toInt()
        : int.tryParse(map['socialApproval']?.toString() ?? '') ?? 0;

    final selectedOptionsRaw = map['selectedOptions'];
    final selectedOptions = selectedOptionsRaw is List
        ? selectedOptionsRaw.whereType<Map>().toList()
        : <Map>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  query.isNotEmpty ? query : 'Untitled decision',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Social $socialApproval%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended: ${recommendedOptionId.isNotEmpty ? recommendedOptionId : '—'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          if (reasoning.isNotEmpty) ...[
            Text(
              reasoning,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (selectedOptions.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Selected (${selectedOptions.length}):',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in selectedOptions)
                  _Chip(
                    // ✅ FIXED: Use 'name' instead of 'title'
                    label:
                        o['name']?.toString() ?? o['title']?.toString() ?? '',
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
