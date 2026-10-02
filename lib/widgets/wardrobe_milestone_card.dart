import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/widgets/section_states.dart';

/// Milestone definition
class WardrobeMilestone {
  final int itemCount;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final bool isUnlocked;

  const WardrobeMilestone({
    required this.itemCount,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    this.isUnlocked = false,
  });
}

/// A card that celebrates wardrobe milestones and encourages user engagement.
class WardrobeMilestoneCard extends ConsumerStatefulWidget {
  const WardrobeMilestoneCard({super.key});

  @override
  ConsumerState<WardrobeMilestoneCard> createState() => _WardrobeMilestoneCardState();
}

class _WardrobeMilestoneCardState extends ConsumerState<WardrobeMilestoneCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissMilestone() {
    setState(() {
      _isDismissed = true;
    });
  }

  List<WardrobeMilestone> _getMilestones(int itemCount) {
    return [
      WardrobeMilestone(
        itemCount: 1,
        title: 'First Piece!',
        description: 'Your wardrobe journey begins',
        emoji: '🌱',
        color: Color(0xFF4CAF50),
        isUnlocked: itemCount >= 1,
      ),
      WardrobeMilestone(
        itemCount: 5,
        title: 'Getting Started',
        description: '5 items curated with care',
        emoji: '✨',
        color: Color(0xFF2196F3),
        isUnlocked: itemCount >= 5,
      ),
      WardrobeMilestone(
        itemCount: 10,
        title: 'Style Explorer',
        description: '10 pieces defining your style',
        emoji: '🎨',
        color: Color(0xFF9C27B0),
        isUnlocked: itemCount >= 10,
      ),
      WardrobeMilestone(
        itemCount: 25,
        title: 'Fashion Forward',
        description: '25 items - a curated collection',
        emoji: '👗',
        color: Color(0xFFFF9800),
        isUnlocked: itemCount >= 25,
      ),
      WardrobeMilestone(
        itemCount: 50,
        title: 'Style Master',
        description: '50 pieces of fashion excellence',
        emoji: '👑',
        color: Color(0xFFE91E63),
        isUnlocked: itemCount >= 50,
      ),
      WardrobeMilestone(
        itemCount: 100,
        title: 'Wardrobe Legend',
        description: '100 items - a fashion empire',
        emoji: '🏆',
        color: Color(0xFFFFD700),
        isUnlocked: itemCount >= 100,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final uid = authAsync.valueOrNull?.id;
    
    if (uid == null || _isDismissed) return SizedBox.shrink();

    final wardrobeAsync = ref.watch(wardrobeProvider);
    
    return wardrobeAsync.when(
      loading: () => SizedBox.shrink(),
      error: (error, _) => ErrorSection(
        title: 'Couldn\u2019t load your wardrobe',
        message: error.toString(),
        compact: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onRetry: () => ref.invalidate(wardrobeProvider),
      ),
      data: (wardrobeState) {
        final itemCount = wardrobeState.items.length;
        final milestones = _getMilestones(itemCount);
        
        // Find the next milestone to achieve
        final nextMilestone = milestones.firstWhere(
          (m) => !m.isUnlocked,
          orElse: () => milestones.last,
        );
        
        // Find the most recently achieved milestone
        final achievedMilestones = milestones.where((m) => m.isUnlocked).toList();
        final latestAchieved = achievedMilestones.isNotEmpty ? achievedMilestones.last : null;
        
        // Calculate progress to next milestone
        final progress = itemCount / nextMilestone.itemCount;
        
        // Show widget if user has items and hasn't dismissed
        if (itemCount == 0) {
          return _buildEmptyState(context);
        }
        
        // Show celebration if just achieved a new milestone
        if (latestAchieved != null && itemCount == latestAchieved.itemCount) {
          _controller.forward(from: 0);
          return _buildCelebrationCard(context, latestAchieved, itemCount, progress, nextMilestone);
        }
        
        // Show progress card
        return _buildProgressCard(context, itemCount, progress, nextMilestone);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Semantics(
      label: 'Start your wardrobe journey. Tap to add your first piece.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => context.go(AppRoutes.wardrobe),
          child: Container(
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.trenzyColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Semantics(
                  label: 'Wardrobe icon',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.checkroom_rounded, color: context.trenzyColors.primary, size: 24),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Your Wardrobe',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.trenzyColors.foreground,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Add your first piece to begin your style journey',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.trenzyColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Navigate to wardrobe',
                  child: Icon(Icons.chevron_right_rounded, color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationCard(
    BuildContext context,
    WardrobeMilestone milestone,
    int itemCount,
    double progress,
    WardrobeMilestone nextMilestone,
  ) {
    return Semantics(
      label: 'Milestone achieved! ${milestone.title}. ${milestone.description}. You have $itemCount items in your wardrobe.',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        milestone.color.withValues(alpha: 0.15),
                        milestone.color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: milestone.color.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: milestone.color.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Celebration emoji
                      Semantics(
                        label: 'Celebration',
                        child: Text(
                          milestone.emoji,
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Milestone achieved text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: milestone.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MILESTONE ACHIEVED!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: milestone.color,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Title
                      Text(
                        milestone.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.trenzyColors.foreground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      // Description
                      Text(
                        milestone.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.trenzyColors.mutedFg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      // Stats row
                      Semantics(
                        label: 'You have $itemCount items. ${nextMilestone.itemCount - itemCount} items needed for next milestone.',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatChip(
                              label: 'Items',
                              value: '$itemCount',
                              color: milestone.color,
                            ),
                            SizedBox(width: 16),
                            _StatChip(
                              label: 'Next',
                              value: '${nextMilestone.itemCount - itemCount}',
                              color: context.trenzyColors.mutedFg,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      // Progress bar to next milestone
                      if (itemCount < nextMilestone.itemCount) ...[
                        Semantics(
                          label: 'Progress to next milestone: ${(progress * 100).toInt()} percent',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: context.trenzyColors.glass,
                              valueColor: AlwaysStoppedAnimation(milestone.color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}% to ${nextMilestone.title}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: 'View your wardrobe',
                              button: true,
                              child: GestureDetector(
                                onTap: () => context.go(AppRoutes.wardrobe),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: GlassGradients.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'View Wardrobe',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: context.trenzyColors.primaryFg,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Semantics(
                            label: 'Dismiss this milestone celebration',
                            button: true,
                            child: GestureDetector(
                              onTap: _dismissMilestone,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.trenzyColors.glass,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.trenzyColors.glassBorder),
                                ),
                                child: Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.trenzyColors.mutedFg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    int itemCount,
    double progress,
    WardrobeMilestone nextMilestone,
  ) {
    return Semantics(
      label: 'Wardrobe progress. $itemCount items. ${nextMilestone.itemCount - itemCount} items needed for ${nextMilestone.title}.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => context.go(AppRoutes.wardrobe),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.trenzyColors.graphite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.trenzyColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      label: 'Next milestone: ${nextMilestone.title}',
                      child: Text(
                        nextMilestone.emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wardrobe Progress',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.trenzyColors.foreground,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '$itemCount items • ${nextMilestone.itemCount - itemCount} to ${nextMilestone.title}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.trenzyColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Navigate to wardrobe',
                      child: Icon(Icons.chevron_right_rounded, color: context.trenzyColors.mutedFg),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Progress bar
                Semantics(
                  label: 'Progress: ${(progress * 100).toInt()} percent complete',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: context.trenzyColors.glass,
                      valueColor: AlwaysStoppedAnimation(nextMilestone.color),
                      minHeight: 8,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // Milestone indicators
                Semantics(
                  label: 'Milestone indicators: 1, 5, 10, 25, 50, 100 items',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MilestoneIndicator(
                        emoji: '🌱',
                        label: '1',
                        isAchieved: itemCount >= 1,
                      ),
                      _MilestoneIndicator(
                        emoji: '✨',
                        label: '5',
                        isAchieved: itemCount >= 5,
                      ),
                      _MilestoneIndicator(
                        emoji: '🎨',
                        label: '10',
                        isAchieved: itemCount >= 10,
                      ),
                      _MilestoneIndicator(
                        emoji: '👗',
                        label: '25',
                        isAchieved: itemCount >= 25,
                      ),
                      _MilestoneIndicator(
                        emoji: '👑',
                        label: '50',
                        isAchieved: itemCount >= 50,
                      ),
                      _MilestoneIndicator(
                        emoji: '🏆',
                        label: '100',
                        isAchieved: itemCount >= 100,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneIndicator extends StatelessWidget {
  const _MilestoneIndicator({
    required this.emoji,
    required this.label,
    required this.isAchieved,
  });

  final String emoji;
  final String label;
  final bool isAchieved;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label items milestone ${isAchieved ? "achieved" : "not yet achieved"}',
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isAchieved
                  ? context.trenzyColors.primary.withValues(alpha: 0.2)
                  : context.trenzyColors.glass,
              shape: BoxShape.circle,
              border: Border.all(
                color: isAchieved
                    ? context.trenzyColors.primary
                    : context.trenzyColors.glassBorder,
                width: isAchieved ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAchieved
                  ? context.trenzyColors.primary
                  : context.trenzyColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}