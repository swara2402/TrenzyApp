import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/glass_theme.dart';

/// Search suggestions screen — shown when the user taps the search bar
/// but hasn't submitted a full query yet. Surfaces recent searches and
/// curated trending terms so they can jump straight to results.
class SuggestionsScreen extends ConsumerWidget {
  final String query;

  const SuggestionsScreen({super.key, required this.query});

  static const _trending = [
    'Oversized blazer',
    'Minimal sneakers',
    'Streetwear hoodie',
    'Linen trousers',
    'Gold jewelry',
    'Leather bag',
    'Y2K aesthetic',
    'Quiet luxury',
  ];

  void _search(BuildContext context, String term) {
    context.push('${AppRoutes.search}?q=${Uri.encodeComponent(term)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.trenzyColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GlassBackButton(),
        title: Text(
          'Suggestions',
          style: GlassTypography.display(
            fontSize: 18,
            color: c.foreground,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (query.isNotEmpty) ...[
            _SectionHeader(label: 'Search for'),
            _SuggestionTile(
              icon: Icons.search_rounded,
              label: '"$query"',
              onTap: () => _search(context, query),
            ),
            const SizedBox(height: 24),
          ],
          _SectionHeader(label: 'Trending'),
          ..._trending.map(
            (term) => _SuggestionTile(
              icon: Icons.trending_up_rounded,
              label: term,
              onTap: () => _search(context, term),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: GlassTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: context.trenzyColors.primary,
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.mutedFg),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GlassTypography.body(
                  fontSize: 15,
                  color: c.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.north_west_rounded, size: 14, color: c.mutedFg),
          ],
        ),
      ),
    );
  }
}