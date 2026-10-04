import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/blend_model.dart';
import '../providers/blend_dashboard_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';
import '../services/blend_socket_service.dart';

class BlendDashboardScreen extends ConsumerStatefulWidget {
  const BlendDashboardScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  ConsumerState<BlendDashboardScreen> createState() => _BlendDashboardScreenState();
}

class _BlendDashboardScreenState extends ConsumerState<BlendDashboardScreen> {
  StreamSubscription? _stateSub;
  BlendLiveState? _liveState;

  @override
  void initState() {
    super.initState();
    if (widget.groupId.isNotEmpty) {
      _listenToLiveState();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  void _listenToLiveState() {
    _stateSub = BlendSocketService.instance.stateStream.listen((state) {
      if (mounted && state.groupId == widget.groupId) {
        setState(() => _liveState = state);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.trenzyColors.glass,
                  border: Border.all(color: context.trenzyColors.glassBorder),
                ),
                child: Icon(Icons.dashboard_outlined, color: context.trenzyColors.primary, size: 36),
              ),
              SizedBox(height: 20),
              DisplayText('No blend selected', fontSize: 18, weight: FontWeight.w600),
              SizedBox(height: 16),
              GlowButton(label: 'Go to Blend Hub', width: 180, height: 46, onTap: () => context.go(AppRoutes.blendHub)),
            ],
          ),
        ),
      );
    }

    final dashboardAsync = ref.watch(blendDashboardProvider(widget.groupId));

    return dashboardAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(child: LoadingSkeletonShimmer(height: 400, radius: 20)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.trenzyColors.crimson, size: 48),
              SizedBox(height: 16),
              DisplayText('Could not load dashboard', fontSize: 16),
              SizedBox(height: 12),
              GlowButton(label: 'Retry', width: 120, height: 40, onTap: () => ref.invalidate(blendDashboardProvider(widget.groupId))),
            ],
          ),
        ),
      ),
      data: (dashboard) => _BlendDashboardContent(
        dashboard: dashboard,
        groupId: widget.groupId,
        liveState: _liveState,
        onRefresh: () => ref.invalidate(blendDashboardProvider(widget.groupId)),
      ),
    );
  }
}

class _BlendDashboardContent extends ConsumerWidget {
  const _BlendDashboardContent({
    required this.dashboard,
    required this.groupId,
    this.liveState,
    required this.onRefresh,
  });

  final BlendDashboard dashboard;
  final String groupId;
  final BlendLiveState? liveState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: context.trenzyColors.primary,
        backgroundColor: context.trenzyColors.graphite,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildCompatibilitySection(context)),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (dashboard.insights.isNotEmpty)
              SliverToBoxAdapter(child: _buildInsightsPanel(context)),
            if (dashboard.insights.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (dashboard.wishlistItems.isNotEmpty)
              SliverToBoxAdapter(child: _buildMiniWishlist(context)),
            if (dashboard.wishlistItems.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (dashboard.moodboardItems.isNotEmpty)
              SliverToBoxAdapter(child: _buildMiniMoodboard(context)),
            if (dashboard.moodboardItems.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (dashboard.styleDNA != null)
              SliverToBoxAdapter(child: _buildStyleDNASection(context)),
            if (dashboard.styleDNA != null)
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (dashboard.recentActivity.isNotEmpty)
              SliverToBoxAdapter(child: _buildActivityFeed(context)),
            SliverToBoxAdapter(child: SizedBox(height: 40)),
            SliverToBoxAdapter(child: _buildMembersSection(context)),
            SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: context.trenzyColors.background.withValues(alpha: 0.8),
      pinned: true,
      elevation: 0,
      leading: GlassBackButton(onTap: () => context.go(AppRoutes.blendHub)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dashboard.name,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground),
          ),
          Text(
            '${dashboard.memberCount} ${dashboard.memberCount == 1 ? 'member' : 'members'}',
            style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
        ],
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
          child: PopupMenuButton<String>(
            color: context.trenzyColors.graphite,
            icon: Icon(Icons.more_horiz, color: context.trenzyColors.mutedFg, size: 18),
            onSelected: (value) {
              switch (value) {
                case 'chat':
                  context.go('${AppRoutes.blendChat}?groupId=$groupId');
                  break;
                case 'settings':
                  break;
                case 'results':
                  context.go('${AppRoutes.blendResults}?groupId=$groupId');
                  break;
                case 'leave':
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'chat', child: ListTile(leading: Icon(Icons.chat, color: context.trenzyColors.primary, size: 20), title: Text('Chat', style: TextStyle(color: context.trenzyColors.foreground)), dense: true)),
              PopupMenuItem(value: 'results', child: ListTile(leading: Icon(Icons.analytics, color: context.trenzyColors.primary, size: 20), title: Text('Results', style: TextStyle(color: context.trenzyColors.foreground)), dense: true)),
              PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings, color: context.trenzyColors.mutedFg, size: 20), title: Text('Settings', style: TextStyle(color: context.trenzyColors.foreground)), dense: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilitySection(BuildContext context) {
    final pct = dashboard.fashionScore / 100.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.trenzyColors.graphite,
              context.trenzyColors.glass,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPATIBILITY',
                      style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      dashboard.compatibilityLevel.isNotEmpty ? dashboard.compatibilityLevel : 'Getting Started',
                      style: TextStyle(fontSize: 14, color: context.trenzyColors.foreground, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.trenzyColors.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${dashboard.totalSwipes} swipes',
                    style: TextStyle(fontSize: 11, color: context.trenzyColors.emerald, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: context.trenzyColors.glass.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(context.trenzyColors.primary),
                minHeight: 8,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '${dashboard.fashionScore}%',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: context.trenzyColors.foreground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _ActionButton(icon: Icons.swipe, label: 'Swipe', color: context.trenzyColors.primary, onTap: () => context.go('${AppRoutes.blendSwipe}?groupId=$groupId')),
          SizedBox(width: 12),
          _ActionButton(icon: Icons.chat, label: 'Chat', color: context.trenzyColors.emerald, onTap: () => context.go('${AppRoutes.blendChat}?groupId=$groupId')),
          SizedBox(width: 12),
          _ActionButton(icon: Icons.favorite, label: 'Wishlist', color: context.trenzyColors.crimson, onTap: () => context.go('${AppRoutes.blendWishlist}?groupId=$groupId')),
          SizedBox(width: 12),
          _ActionButton(icon: Icons.dashboard, label: 'Moodboard', color: context.trenzyColors.primary, onTap: () => context.go('${AppRoutes.blendMoodboard}?groupId=$groupId')),
        ],
      ),
    );
  }

  Widget _buildInsightsPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI INSIGHTS',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.auto_awesome, color: context.trenzyColors.primary, size: 16),
            ],
          ),
          SizedBox(height: 12),
          ...dashboard.insights.take(3).map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightCard(insight: insight),
          )),
          if (dashboard.insights.length > 3)
            Center(
              child: TextButton(
                onPressed: () => context.go('${AppRoutes.blendDashboard}?groupId=$groupId'),
                child: Text('View all ${dashboard.insights.length} insights', style: TextStyle(color: context.trenzyColors.primary, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniWishlist(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SHARED WISHLIST',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () => context.go('${AppRoutes.blendWishlist}?groupId=$groupId'),
                child: Text('See all (${dashboard.totalWishlistItems})', style: TextStyle(fontSize: 11, color: context.trenzyColors.mutedFg)),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dashboard.wishlistItems.length,
              separatorBuilder: (_, _) => SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = dashboard.wishlistItems[index];
                return _MiniWishlistCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMoodboard(BuildContext context) {
    final items = dashboard.moodboardItems;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MOODBOARD',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () => context.go('${AppRoutes.blendMoodboard}?groupId=$groupId'),
                child: Text('See all (${dashboard.totalMoodboardItems})', style: TextStyle(fontSize: 11, color: context.trenzyColors.mutedFg)),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length.clamp(0, 6),
              separatorBuilder: (_, _) => SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _MiniMoodboardCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleDNASection(BuildContext context) {
    final dna = dashboard.styleDNA!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.trenzyColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome, color: context.trenzyColors.primary, size: 14),
              ),
              SizedBox(width: 8),
              Text(
                'STYLE DNA',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildDnaRow('Colors', dna.colors, context),
          if (dna.brands.isNotEmpty) ...[SizedBox(height: 12), _buildDnaRow('Brands', dna.brands, context)],
          if (dna.categories.isNotEmpty) ...[SizedBox(height: 12), _buildDnaRow('Categories', dna.categories, context)],
          if (dna.aesthetics.isNotEmpty) ...[SizedBox(height: 12), _buildDnaRow('Aesthetics', dna.aesthetics, context)],
          if (dna.occasions.isNotEmpty) ...[SizedBox(height: 12), _buildDnaRow('Occasions', dna.occasions, context)],
        ],
      ),
    );
  }

  Widget _buildDnaRow(String label, List<StyleDnaItem> items, BuildContext context) {
    if (items.isEmpty) return SizedBox.shrink();
    final topItems = items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.trenzyColors.mutedFg, fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        Row(
          children: topItems.map((item) {
            final isTop = item == topItems.first;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isTop ? context.trenzyColors.primary.withValues(alpha: 0.12) : context.trenzyColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isTop ? context.trenzyColors.primary.withValues(alpha: 0.3) : context.trenzyColors.glassBorder),
                ),
                child: Text(
                  '${item.name} ${item.confidence.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                    color: isTop ? context.trenzyColors.primary : context.trenzyColors.foreground,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivityFeed(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT ACTIVITY',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          ...dashboard.recentActivity.take(5).map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityRow(event: event),
          )),
        ],
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBERS',
            style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: dashboard.members.map((member) {
              return Column(
                children: [
                  Container(
                    width: 52, height: 52,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [context.trenzyColors.primary, context.trenzyColors.emerald]),
                    ),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: context.trenzyColors.graphite),
                      child: Center(
                        child: Text(
                          member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                          style: TextStyle(color: context.trenzyColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(member.userName, style: TextStyle(fontSize: 12, color: context.trenzyColors.foreground)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: context.trenzyColors.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 10, color: context.trenzyColors.foreground, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final BlendInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.trenzyColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lightbulb_outline, color: context.trenzyColors.primary, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.trenzyColors.foreground)),
                SizedBox(height: 4),
                Text(insight.description, style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg)),
              ],
            ),
          ),
          if (insight.confidence > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: insight.confidence >= 0.7 ? context.trenzyColors.emerald.withValues(alpha: 0.12) : context.trenzyColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(insight.confidence * 100).round()}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: insight.confidence >= 0.7 ? context.trenzyColors.emerald : context.trenzyColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniWishlistCard extends StatelessWidget {
  final SharedWishlistItem item;

  const _MiniWishlistCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: item.productImage != null
                ? CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover, width: double.infinity, placeholder: (_, _) => Container(color: context.trenzyColors.glass), errorWidget: (_, _, _) => Icon(Icons.image, color: context.trenzyColors.mutedFg))
                : Container(color: context.trenzyColors.glass, child: Center(child: Icon(Icons.image_outlined, color: context.trenzyColors.mutedFg))),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.trenzyColors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.productBrand != null)
                  Text(item.productBrand!, style: TextStyle(fontSize: 10, color: context.trenzyColors.mutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMoodboardCard extends StatelessWidget {
  final MoodboardItem item;

  const _MiniMoodboardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100, height: 120,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover, width: double.infinity, placeholder: (_, _) => Center(child: CircularProgressIndicator(color: context.trenzyColors.primary, strokeWidth: 2)), errorWidget: (_, _, _) => Icon(Icons.image, color: context.trenzyColors.mutedFg)),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEvent event;

  const _ActivityRow({required this.event});

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'wishlist_added': return Icons.favorite;
      case 'moodboard_added': return Icons.palette;
      case 'blend_updated': return Icons.settings;
      case 'swipe': return Icons.swipe;
      case 'member_joined': return Icons.person_add;
      case 'member_left': return Icons.person_remove;
      case 'vote_completed': return Icons.how_to_vote;
      default: return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: context.trenzyColors.glass,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconForKind(event.kind), color: context.trenzyColors.primary, size: 14),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(event.description, style: TextStyle(fontSize: 12, color: context.trenzyColors.foreground)),
        ),
      ],
    );
  }
}
