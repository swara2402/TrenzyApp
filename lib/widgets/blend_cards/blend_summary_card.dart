import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/blend_model.dart';
import '../../router/app_router.dart';
import '../../theme/glass_theme.dart';

class BlendSummaryCard extends StatelessWidget {
  const BlendSummaryCard({
    super.key,
    required this.results,
    required this.groupId,
    required this.onToggleTheme,
    this.onRefresh,
  });

  final BlendResults results;
  final String groupId;
  final VoidCallback onToggleTheme;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final r = results;
    final levelColor = _levelColor((r.fashionScore ?? 0).toInt());
    final compatLevel = r.compatibilityLevel != null ? '${r.compatibilityLevel}' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlassSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.trenzyColors.primary.withValues(alpha: 0.12),
            context.trenzyColors.primaryDim.withValues(alpha: 0.08),
            context.trenzyColors.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: context.trenzyColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Blend Recap',
                style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.groupName ?? '',
            style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Fashion Score',
                  value: '${r.fashionScore ?? 0}%',
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Compatibility',
                  value: compatLevel.isNotEmpty ? compatLevel : 'N/A',
                  color: levelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Shared Brands',
                  value: '${r.sharedBrands?.length ?? 0}',
                  color: context.trenzyColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Shared Styles',
                  value: '${r.sharedStyles?.length ?? 0}',
                  color: context.trenzyColors.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Swipes',
                  value: '${r.totalSwipes ?? 0}',
                  color: context.trenzyColors.fg60,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Wardrobe Overlap',
                  value: '${r.wardrobeOverlap ?? 0}',
                  color: context.trenzyColors.fg60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.push(
                  '${AppRoutes.blendChat}?groupId=$groupId',
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Start Blend Chat'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pop();
              },
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View Winners'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(
                  '${AppRoutes.blendLobby}?groupId=$groupId',
                );
              },
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('Create Group Blend'),
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 55) return Colors.blue;
    if (score >= 35) return Colors.orange;
    return Colors.red;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GlassTypography.body(fontSize: 20, weight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GlassTypography.body(fontSize: 12, weight: FontWeight.w600, color: context.trenzyColors.mutedFg),
          ),
        ],
      ),
    );
  }
}
