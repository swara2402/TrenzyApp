import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/blend_model.dart';
import '../providers/blend_provider.dart';
import '../router/app_router.dart';
import '../widgets/app_widgets.dart';

class _BlendResultsLoadingSkeleton extends StatelessWidget {
  const _BlendResultsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeletonShimmer(height: 20, width: 220, radius: 12),
                  const SizedBox(height: 8),
                  LoadingSkeletonShimmer(height: 16, width: 160, radius: 10),
                  const SizedBox(height: 18),
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LoadingSkeletonShimmer(height: 16, width: 240, radius: 12),
                  const SizedBox(height: 14),
                  for (var i = 0; i < 2; i++) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LoadingSkeletonShimmer(
                            height: 16,
                            width: 180,
                            radius: 10,
                          ),
                          const SizedBox(height: 12),
                          LoadingSkeletonShimmer(
                            height: 14,
                            width: 220,
                            radius: 10,
                          ),
                          const SizedBox(height: 8),
                          LoadingSkeletonShimmer(
                            height: 14,
                            width: 160,
                            radius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  LoadingSkeletonShimmer(
                    height: 44,
                    width: double.infinity,
                    radius: 18,
                  ),
                  const SizedBox(height: 12),
                  LoadingSkeletonShimmer(
                    height: 44,
                    width: double.infinity,
                    radius: 18,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class BlendResultsScreen extends ConsumerWidget {
  const BlendResultsScreen({
    super.key,
    required this.onToggleTheme,
    required this.groupId,
  });

  final VoidCallback onToggleTheme;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(blendResultsProvider(groupId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: resultsAsync.when(
          loading: () => const _BlendResultsLoadingSkeleton(),
          error: (e, _) => AsyncRetryErrorState(
            title: 'Failed to load results',
            message: e.toString(),
            onRetry: () => ref.invalidate(blendResultsProvider(groupId)),
          ),
          data: (results) => CustomScrollView(
            slivers: [
              AppTopBar(
                leading: Icons.arrow_back_rounded,
                trailing: Icons.refresh_rounded,
                onLeadingPressed: () => context.pop(),
                onTrailingPressed: () =>
                    ref.invalidate(blendResultsProvider(groupId)),
                onToggleTheme: onToggleTheme,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Blend Results',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      results.groupName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${results.memberCount} members · ${results.totalSwipes} swipes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    if (results.overallWinner != null)
                      _WinnerBanner(
                        title: results.overallTie
                            ? 'Overall tie — top pick'
                            : 'Overall winner',
                        product: results.overallWinner!,
                        isTie: results.overallTie,
                      ),
                    if (results.winners.isEmpty)
                      const FriendlyEmptyState(
                        title: 'No swipes yet',
                        message:
                            'Start swiping in the blend to see ranked picks.',
                        icon: Icons.swipe_rounded,
                      )
                    else ...[
                      Text(
                        'Category winners',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final winner in results.winners)
                        _CategoryWinnerCard(winner: winner),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        context.push(AppRoutes.blendLobby, extra: groupId);
                      },
                      child: const Text('Back to Lobby'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(AppRoutes.blendChat, extra: groupId);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Open Chat'),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({
    required this.title,
    required this.product,
    required this.isTie,
  });

  final String title;
  final BlendRankedProduct product;
  final bool isTie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.85),
            theme.colorScheme.secondary.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isTie) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('TIE'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ✅ FIXED: Use product.name instead of product.title
          Text(
            product.product.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${product.product.formattedPrice} · score ${product.score}',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CategoryWinnerCard extends StatelessWidget {
  const _CategoryWinnerCard({required this.winner});

  final BlendCategoryWinner winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  winner.category,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (winner.isTie)
                  const Chip(
                    label: Text('Tie'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final product in winner.products)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ FIXED: Use product.product.name
                          Text(
                            product.product.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${product.product.formattedPrice} · score ${product.score}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${product.loveCount}❤️ ${product.likeCount}👍',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
