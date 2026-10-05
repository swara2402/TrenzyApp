import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/providers/wishlist_provider.dart';
import 'package:trenzy/models/blend_model.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/widgets/section_states.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trenzy/analytics/events.dart';

Future<void> _saveToWishlist(
  BuildContext context,
  WidgetRef ref,
  ProductModel product,
) async {
  HapticFeedback.mediumImpact();
  await ref.read(wishlistProvider.notifier).toggle(product.id);
  if (context.mounted) {
    GlassToast.success(context, 'Saved to wishlist');
  }
}

class BlendResultsScreen extends ConsumerWidget {
  const BlendResultsScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: EmptySection(
            title: 'No results available',
            subtitle: 'Select an active blend group to view results.',
            actionLabel: 'Go to Blend Hub',
            onAction: () => context.go(AppRoutes.blendHub),
          ),
        ),
      );
    }

    final resultsAsync = ref.watch(blendResultsProvider(groupId));

    return resultsAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(child: LoadingSkeletonShimmer(height: 200, radius: 20)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: ErrorSection(
            title: 'Could not load results',
            message: friendlyError(err),
            onRetry: () => ref.invalidate(blendResultsProvider(groupId)),
          ),
        ),
      ),
      data: (results) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          trackBlendResultsViewed(
            ref,
            groupId,
            fashionScore: (results.fashionScore ?? 0).toInt(),
          );
        });
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(blendResultsProvider(groupId)),
          child: _BlendResultsContent(results: results),
        );
      },
    );
  }
}

class _BlendResultsContent extends StatelessWidget {
  const _BlendResultsContent({required this.results});

  final BlendResults results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: context.trenzyColors.background.withValues(
              alpha: 0.8,
            ),
            pinned: true,
            elevation: 0,
            leading: GlassBackButton(),
            title: DisplayText(
              results.groupName?.isNotEmpty == true
                  ? results.groupName!
                  : 'Blend Results',
              fontSize: 20,
            ),
            actions: [
              // Share button
              Semantics(
                label: 'Share blend results',
                button: true,
                child: IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    color: context.trenzyColors.primary,
                  ),
                  onPressed: () => _shareResults(context),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildScoreSection(context)),
          SliverToBoxAdapter(child: _buildCompatibilityNarrative(context)),
          SliverToBoxAdapter(child: _buildInfoSection()),
          if (results.sharedStyles?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildSharedSection(
                context,
                'Shared Styles',
                results.sharedStyles!,
              ),
            ),
          if (results.sharedBrands?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildSharedSection(
                context,
                'Shared Brands',
                results.sharedBrands!,
              ),
            ),
          if (results.sharedCategories?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _buildSharedSection(
                context,
                'Shared Categories',
                results.sharedCategories!,
              ),
            ),
          if (results.categoryWinners?.isNotEmpty == true || results.winners?.isNotEmpty == true)
            SliverToBoxAdapter(child: _buildWinnersSection(context))
          else if (results.overallWinner == null)
            SliverToBoxAdapter(
              child: EmptySection(
                title: 'Keep swiping — results get better with more votes',
                subtitle: 'Your group hasn\u2019t voted on enough items yet.',
                icon: Icons.style_rounded,
                actionLabel: 'Keep Swiping',
                onAction: () => context.go(
                  '${AppRoutes.blendSwipe}?groupId=${results.groupId}',
                ),
              ),
            ),
          SliverToBoxAdapter(child: _buildActionSection(context)),
          SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context) {
    final score = results.fashionScore ?? 0.0;
    final level = results.compatibilityLevel != null ? '${results.compatibilityLevel}' : '';

    // Determine emoji for accessibility
    String accessibilityEmoji;
    if (score >= 80) {
      accessibilityEmoji = 'High compatibility';
    } else if (score >= 60) {
      accessibilityEmoji = 'Good compatibility';
    } else if (score >= 40) {
      accessibilityEmoji = 'Moderate compatibility';
    } else {
      accessibilityEmoji = 'Low compatibility';
    }

    // Determine color based on score
    Color scoreColor;
    String emoji;
    if (score >= 80) {
      scoreColor = context.trenzyColors.emerald;
      emoji = '🔥';
    } else if (score >= 60) {
      scoreColor = context.trenzyColors.primary;
      emoji = '✨';
    } else if (score >= 40) {
      scoreColor = Colors.amber;
      emoji = '💡';
    } else {
      scoreColor = context.trenzyColors.mutedFg;
      emoji = '🤔';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
      child: Column(
        children: [
          // Status badge
          Semantics(
            label: 'Match analysis complete',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                'MATCH ANALYSIS COMPLETE',
                style: TextStyle(
                  fontSize: 10,
                  color: scoreColor,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 32),
          // Big score with emoji
          Semantics(
            label:
                'Style compatibility score: $score percent. $accessibilityEmoji.',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: TextStyle(fontSize: 40)),
                SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    text: '$score',
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                    children: [
                      TextSpan(
                        text: '%',
                        style: TextStyle(
                          fontSize: 40,
                          color: GlassColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Semantics(
            label: 'Style Compatibility',
            child: Text(
              'STYLE COMPATIBILITY',
              style: TextStyle(
                fontSize: 12,
                color: GlassColors.mutedFg,
                letterSpacing: 3,
              ),
            ),
          ),
          SizedBox(height: 8),
          if (level.isNotEmpty)
            Semantics(
              label: 'Compatibility level: $level',
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 16,
                  color: scoreColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityNarrative(BuildContext context) {
    // Generate a human-readable narrative based on the results
    final narratives = <String>[];

    if (results.sharedStyles?.isNotEmpty == true) {
      narratives.add(
        'You and your group share a love for ${results.sharedStyles!.first} style',
      );
    }
    if ((results.sharedBrands?.length ?? 0) >= 2) {
      narratives.add(
        'Top brand matches: ${results.sharedBrands!.take(2).join(" and ")}',
      );
    }
    if ((results.wardrobeOverlap ?? 0) > 0) {
      narratives.add(
        '${results.wardrobeOverlap} shared wardrobe items show strong style alignment',
      );
    }

    if (narratives.isEmpty) {
      narratives.add(
        'Your group is discovering new style territories together',
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.trenzyColors.primary.withValues(alpha: 0.08),
            context.trenzyColors.emerald.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.trenzyColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: context.trenzyColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'YOUR STYLE STORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.trenzyColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...narratives.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: context.trenzyColors.primary),
                  ),
                  Expanded(
                    child: Text(
                      n,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.trenzyColors.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _InfoChip(
            label: 'Members',
            value: '${results.memberCount}',
            icon: Icons.people_rounded,
          ),
          SizedBox(width: 12),
          _InfoChip(
            label: 'Total Swipes',
            value: '${results.totalSwipes}',
            icon: Icons.swipe,
          ),
          if ((results.wardrobeOverlap ?? 0) > 0) ...[
            SizedBox(width: 12),
            _InfoChip(
              label: 'Wardrobe Overlap',
              value: '${results.wardrobeOverlap}',
              icon: Icons.checkroom,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedSection(
    BuildContext context,
    String title,
    List<String> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: GlassColors.primary,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: GlassColors.glass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GlassColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: context.trenzyColors.emerald,
                    ),
                    SizedBox(width: 6),
                    Text(
                      item,
                      style: TextStyle(
                        color: GlassColors.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.trenzyColors.primary,
                      context.trenzyColors.emerald,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'TOP PICKS',
                style: TextStyle(
                  fontSize: 14,
                  color: context.trenzyColors.primary,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...(results.categoryWinners ?? []).map((catWinner) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        catWinner.category ?? 'Winner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.trenzyColors.foreground,
                        ),
                      ),
                      if (catWinner.winner?.isTie == true)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.trenzyColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: context.trenzyColors.primary.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Text(
                            'TIE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.trenzyColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: (catWinner.products ?? (catWinner.winner != null ? [catWinner.winner!] : [])).map((rp) {
                        return _WinnerProductCard(rankedProduct: rp);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (results.overallWinner != null) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.trenzyColors.primary.withValues(alpha: 0.1),
                    context.trenzyColors.emerald.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: context.trenzyColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'OVERALL WINNER',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.trenzyColors.primary,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _WinnerProductCard(
                    rankedProduct: results.overallWinner!,
                    isLarge: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: "What's next section",
            child: Text(
              "WHAT'S NEXT",
              style: TextStyle(
                fontSize: 12,
                color: context.trenzyColors.primary,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Shared Wishlist CTA
          Semantics(
            label: 'View shared wishlist. View all items your group loved.',
            button: true,
            child: _ActionCard(
              icon: Icons.shopping_bag_rounded,
              title: 'Shared Wishlist',
              subtitle: 'View all items your group loved',
              onTap: () => context.push('/blend/${results.groupId}/wishlist'),
            ),
          ),
          SizedBox(height: 12),
          // Start New Blend CTA
          Semantics(
            label:
                'Start another blend. Create a new style session with friends.',
            button: true,
            child: _ActionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Start Another Blend',
              subtitle: 'Create a new style session with friends',
              onTap: () => context.go(AppRoutes.blendHub),
            ),
          ),
          SizedBox(height: 12),
          // Explore More CTA
          Semantics(
            label:
                'Explore similar styles. Discover more products matching your taste.',
            button: true,
            child: _ActionCard(
              icon: Icons.explore_rounded,
              title: 'Explore Similar Styles',
              subtitle: 'Discover more products matching your taste',
              onTap: () => context.go(AppRoutes.discover),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareResults(BuildContext context) async {
    final topPicks = (results.topProducts ?? [])
        .map((p) => p.product?.name ?? '')
        .where((name) => name.isNotEmpty)
        .take(3)
        .join(', ');
    final body = StringBuffer('My Blend "${results.groupName}"');
    body.write(' hit ${results.fashionScore}% style compatibility on Trenzy!');
    if (topPicks.isNotEmpty) {
      body.write('\n\nTop picks: $topPicks');
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: body.toString(),
          subject: 'Our Blend results on Trenzy',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the share sheet.')),
        );
      }
    }
  }
}

class _WinnerProductCard extends ConsumerWidget {
  const _WinnerProductCard({required this.rankedProduct, this.isLarge = false});

  final BlendRankedProduct rankedProduct;
  final bool isLarge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = rankedProduct.product;
    final w = isLarge ? double.infinity : 180.0;

    final isStrongAgreement =
        (rankedProduct.matchScore ?? 0) >= 70 || (rankedProduct.loveCount ?? 0) >= 2;
    final consensusLabel = isStrongAgreement ? 'Strong agreement' : 'Split';
    final consensusColor = isStrongAgreement
        ? context.trenzyColors.emerald
        : Colors.amber;

    final ctaLabel = 'Save to wishlist';

    return Container(
      width: w,
      margin: EdgeInsets.only(right: isLarge ? 0 : 12),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLarge
              ? context.trenzyColors.primary.withValues(alpha: 0.3)
              : context.trenzyColors.glassBorder,
        ),
        boxShadow: isLarge
            ? [
                BoxShadow(
                  color: context.trenzyColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: isLarge ? 280 : 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                product?.imageUrl != null && product!.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) => Container(
                          color: context.trenzyColors.graphite,
                          child: Icon(
                            Icons.image_outlined,
                            color: context.trenzyColors.fg20,
                            size: 24,
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: context.trenzyColors.graphite,
                          child: Icon(
                            Icons.image,
                            color: context.trenzyColors.fg20,
                          ),
                        ),
                      )
                    : Container(
                        color: context.trenzyColors.graphite,
                        child: Icon(
                          Icons.image,
                          color: context.trenzyColors.fg20,
                          size: 32,
                        ),
                      ),
                // Consensus strength badge overlay
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.trenzyColors.background.withValues(
                        alpha: 0.85,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: consensusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStrongAgreement
                              ? Icons.local_fire_department
                              : Icons.alt_route,
                          size: 12,
                          color: consensusColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          consensusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: consensusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Product',
                  style: TextStyle(
                    color: context.trenzyColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                // Price with match score
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: isLarge ? GlassGradients.primary : null,
                        color: isLarge ? null : context.trenzyColors.glass,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product?.effectivePrice ?? product?.price ?? 0.0}',
                        style: TextStyle(
                          color: isLarge
                              ? context.trenzyColors.primaryFg
                              : context.trenzyColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((rankedProduct.matchScore ?? 0) > 0) SizedBox(width: 8),
                    if ((rankedProduct.matchScore ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.emerald.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 12,
                              color: context.trenzyColors.emerald,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${rankedProduct.matchScore}%',
                              style: TextStyle(
                                color: context.trenzyColors.emerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Member voting breakdown (if available)
                if ((rankedProduct.loveCount ?? 0) > 0 ||
                    (rankedProduct.likeCount ?? 0) > 0) ...[
                  SizedBox(height: 8),
                  _MemberVotingBreakdown(rankedProduct: rankedProduct),
                ],
                SizedBox(height: 12),
                if (product != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveToWishlist(context, ref, product),
                      icon: Icon(Icons.favorite_border_rounded, size: 16),
                      label: Text(ctaLabel),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: context.trenzyColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.wishlist),
                    icon: Icon(Icons.bookmark_border_rounded, size: 16),
                    label: Text('View saved picks'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.trenzyColors.primary,
                      side: BorderSide(
                        color: context.trenzyColors.primary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
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

class _MemberVotingBreakdown extends StatelessWidget {
  const _MemberVotingBreakdown({required this.rankedProduct});

  final BlendRankedProduct rankedProduct;

  @override
  Widget build(BuildContext context) {
    final totalVotes = (rankedProduct.loveCount ?? 0) + (rankedProduct.likeCount ?? 0);
    if (totalVotes == 0) return SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBER REACTIONS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: context.trenzyColors.mutedFg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              if ((rankedProduct.loveCount ?? 0) > 0)
                _VoteChip(
                  icon: Icons.favorite,
                  count: rankedProduct.loveCount!,
                  color: context.trenzyColors.crimson,
                  label: 'Loved',
                ),
              if ((rankedProduct.loveCount ?? 0) > 0 && (rankedProduct.likeCount ?? 0) > 0)
                SizedBox(width: 8),
              if ((rankedProduct.likeCount ?? 0) > 0)
                _VoteChip(
                  icon: Icons.thumb_up,
                  count: rankedProduct.likeCount!,
                  color: context.trenzyColors.primary,
                  label: 'Liked',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: context.trenzyColors.primary),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.trenzyColors.foreground,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                color: context.trenzyColors.mutedFg,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return Semantics(
      label: '$title. $subtitle.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.trenzyColors.graphite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          child: Row(
            children: [
              Semantics(
                label: '$title icon',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.trenzyColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: context.trenzyColors.primary,
                    size: 22,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.trenzyColors.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Navigate to next section',
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.trenzyColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
