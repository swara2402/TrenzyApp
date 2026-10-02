import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class DiscoverPreferencesScreen extends ConsumerStatefulWidget {
  const DiscoverPreferencesScreen({super.key});

  @override
  ConsumerState<DiscoverPreferencesScreen> createState() =>
      _DiscoverPreferencesScreenState();
}

class _DiscoverPreferencesScreenState
    extends ConsumerState<DiscoverPreferencesScreen> {
  final List<String> _selectedDiscoveries = [];

  // Hardcoded options matching the spec
  static const _discoveries = [
    'Trending outfits',
    'New arrivals',
    'Affordable finds',
    'Premium fashion',
    'Hidden gems',
    'Outfit inspiration',
    'New brands',
    'Celebrity-inspired looks',
    'Seasonal fashion',
  ];

  @override
  void initState() {
    super.initState();
    _restoreFromProvider();
  }

  void _restoreFromProvider() {
    final saved = ref.read(userPreferencesProvider).discoverPreferences;
    if (saved.isNotEmpty) {
      _selectedDiscoveries.addAll(saved);
    }
  }

  void _toggleSelection(String discovery) {
    setState(() {
      if (_selectedDiscoveries.contains(discovery)) {
        _selectedDiscoveries.remove(discovery);
      } else {
        _selectedDiscoveries.add(discovery);
      }
    });
    ref
        .read(userPreferencesProvider.notifier)
        .setDiscoverPreferences(_selectedDiscoveries);
  }

  bool get canContinue => _selectedDiscoveries.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do you want to discover on Trenzy?',
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'What would you love to see more of?',
              style: TextStyle(
                color: context.trenzyColors.mutedFg.withAlpha(179),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: _discoveries.map((discovery) {
                  final isSelected = _selectedDiscoveries.contains(discovery);
                  return ChoiceChip(
                    label: Text(discovery),
                    selected: isSelected,
                    onSelected: (selected) => _toggleSelection(discovery),
                    selectedColor: context.trenzyColors.primary,
                    backgroundColor: Colors.grey[900],
                    labelStyle: TextStyle(
                      color:
                          isSelected ? context.trenzyColors.primaryFg : context.trenzyColors.mutedFg,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? context.trenzyColors.primary
                          : Colors.grey[700]!,
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 24),
            Text(
              '${_selectedDiscoveries.length} selected',
              style: TextStyle(
                color: canContinue
                    ? context.trenzyColors.primary
                    : context.trenzyColors.mutedFg.withAlpha(128),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: 'CONTINUE',
                onTap: canContinue
                    ? () {
                        if (context.mounted) {
                          context.go(AppRoutes.favoriteColors);
                        }
                      }
                    : null,
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
