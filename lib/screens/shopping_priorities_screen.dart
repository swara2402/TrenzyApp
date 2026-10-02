import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class ShoppingPrioritiesScreen extends ConsumerStatefulWidget {
  const ShoppingPrioritiesScreen({super.key});

  @override
  ConsumerState<ShoppingPrioritiesScreen> createState() =>
      _ShoppingPrioritiesScreenState();
}

class _ShoppingPrioritiesScreenState
    extends ConsumerState<ShoppingPrioritiesScreen> {
  final List<String> _selectedPriorities = [];
  final List<String> _selectedColors = [];
  int? _selectedBudgetIndex;

  static const _budgetTiers = [
    (label: 'Under ₹1,000', maxBudget: 1000),
    (label: '₹1,000 – ₹2,500', maxBudget: 2500),
    (label: '₹2,500 – ₹5,000', maxBudget: 5000),
    (label: '₹5,000 – ₹10,000', maxBudget: 10000),
    (label: '₹10,000+ / Premium', maxBudget: 99999),
  ];

  // Canonical colors fetched from /api/persona/colors (single source of truth).
  // Offline fallback matches backend color_taxonomy.py exactly.
  static const _fallbackColors = [
    (name: 'Black', hex: '#000000'),
    (name: 'White', hex: '#FFFFFF'),
    (name: 'Grey', hex: '#9E9E9E'),
    (name: 'Beige', hex: '#F5F5DC'),
    (name: 'Brown', hex: '#795548'),
    (name: 'Navy', hex: '#001F3F'),
    (name: 'Blue', hex: '#2196F3'),
    (name: 'Green', hex: '#4CAF50'),
    (name: 'Red', hex: '#F44336'),
    (name: 'Pink', hex: '#E91E63'),
    (name: 'Yellow', hex: '#FFEB3B'),
    (name: 'Orange', hex: '#FF9800'),
    (name: 'Purple', hex: '#9C27B0'),
    (name: 'Multicolor', hex: '#FF6F00'),
  ];

  // Hardcoded priorities matching the spec
  static const _allPriorities = [
    ('Affordable price', Icons.attach_money_rounded),
    ('Quality', Icons.diamond_rounded),
    ('Comfort', Icons.checkroom_rounded),
    ('Latest trends', Icons.trending_up_rounded),
    ('Brand', Icons.label_rounded),
    ('Unique styles', Icons.auto_awesome_rounded),
    ('Versatility', Icons.swap_horiz_rounded),
    ('Sustainability', Icons.eco_rounded),
  ];

  bool get canContinue =>
      _selectedPriorities.isNotEmpty && _selectedBudgetIndex != null;

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _restoreFromProvider();
  }

  void _restoreFromProvider() {
    final prefs = ref.read(userPreferencesProvider);
    if (prefs.shoppingPriorities.isNotEmpty) {
      _selectedPriorities.addAll(prefs.shoppingPriorities);
    }
    final savedBudget = prefs.budgetMax;
    if (savedBudget != null) {
      for (int i = 0; i < _budgetTiers.length; i++) {
        if (_budgetTiers[i].maxBudget >= savedBudget) {
          _selectedBudgetIndex = i;
          break;
        }
      }
      if (_selectedBudgetIndex == null && savedBudget > 0) {
        _selectedBudgetIndex = _budgetTiers.length - 1;
      }
    }
    if (prefs.preferredColors.isNotEmpty) {
      _selectedColors.addAll(prefs.preferredColors);
    }
  }

  void _togglePriority(String priority) {
    setState(() {
      if (_selectedPriorities.contains(priority)) {
        _selectedPriorities.remove(priority);
      } else {
        if (_selectedPriorities.length < 3) {
          _selectedPriorities.add(priority);
        }
      }
    });
    ref
        .read(userPreferencesProvider.notifier)
        .setShoppingPriorities(_selectedPriorities);
  }

  void _toggleColor(String color) {
    setState(() {
      if (_selectedColors.contains(color)) {
        _selectedColors.remove(color);
      } else {
        _selectedColors.add(color);
      }
    });
    ref.read(userPreferencesProvider.notifier).setColors(_selectedColors);
  }

  void _selectBudget(int index) {
    setState(() {
      if (_selectedBudgetIndex == index) {
        // If clicking the already selected budget, deselect it
        _selectedBudgetIndex = null;
        ref.read(userPreferencesProvider.notifier).setBudget(null);
      } else {
        _selectedBudgetIndex = index;
        ref
            .read(userPreferencesProvider.notifier)
            .setBudget(_budgetTiers[index].maxBudget);
      }
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = ref.read(userPreferencesProvider);
    try {
      await ref
          .read(apiServiceProvider)
          .savePreferences(
            preferredCategories: prefs.preferredCategories,
            preferredBrands: prefs.preferredBrands,
            preferredColors: prefs.preferredColors,
            preferredStyles: prefs.preferredStyles,
            preferredAesthetics: prefs.preferredAesthetics,
            preferredSeasons: prefs.preferredSeasons,
            preferredOccasions: prefs.preferredOccasions,
            budgetMax: prefs.budgetMax,
            discoverPreferences: prefs.discoverPreferences,
            productInterests: prefs.productInterests,
            shoppingPriorities: prefs.shoppingPriorities,
          );
    } catch (_) {
      // Non-blocking — persona generation will retry with local prefs.
    }
    if (mounted) {
      context.go(AppRoutes.persona);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use canonical colors from API; fall back to hardcoded list if API fails.
    final colorsAsync = ref.watch(personaColorsProvider);
    final allColors =
        colorsAsync.whenOrNull(
          data: (list) => list
              .map((c) => (name: c['name'] as String, hex: c['hex'] as String))
              .toList(),
        ) ??
        _fallbackColors;

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => context.go(AppRoutes.preferredStyles),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: LinearProgressIndicator(
                    value: 1, // Step 3 of 3
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.trenzyColors.primary,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Step 3 of 3',
                  style: TextStyle(
                    color: context.trenzyColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              children: [
                Text(
                  'Set your budget & priorities',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'We\u2019ll use this to personalize your recommendations.',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg.withAlpha(179),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 24),
                // ── Budget tiers ───────────────────────────────────────────
                Text(
                  'What\u2019s your usual budget?',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_budgetTiers.length, (index) {
                    final tier = _budgetTiers[index];
                    final isSelected = _selectedBudgetIndex == index;
                    return GestureDetector(
                      onTap: () => _selectBudget(index),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.trenzyColors.primary
                              : context.trenzyColors.fg08,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? context.trenzyColors.primary
                                : context.trenzyColors.glassBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: context.trenzyColors.primary
                                        .withAlpha(77),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          tier.label,
                          style: TextStyle(
                            color: isSelected
                                ? context.trenzyColors.primaryFg
                                : context.trenzyColors.mutedFg,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 28),
                // ── Priorities ─────────────────────────────────────────────
                Text(
                  'What matters most when shopping?',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose up to 3.',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg.withAlpha(179),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: _allPriorities.map((item) {
                    final (label, icon) = item;
                    final isSelected = _selectedPriorities.contains(label);
                    return GestureDetector(
                      onTap: () => _togglePriority(label),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.trenzyColors.primary
                              : context.trenzyColors.fg08,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? context.trenzyColors.primary
                                : context.trenzyColors.glassBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: context.trenzyColors.primary
                                        .withAlpha(77),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: isSelected
                                  ? context.trenzyColors.primaryFg
                                  : context.trenzyColors.mutedFg,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.trenzyColors.primaryFg
                                      : context.trenzyColors.mutedFg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),
                // ── Colors ──────────────────────────────────────────────────
                Text(
                  'Which colors do you wear most?',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Optional — helps us match pieces you\u2019ll actually wear.',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg.withAlpha(179),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allColors.map((item) {
                    final name = item.name;
                    final isSelected = _selectedColors.contains(name);
                    return GestureDetector(
                      onTap: () => _toggleColor(name),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.trenzyColors.primary
                              : context.trenzyColors.fg08,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? context.trenzyColors.primary
                                : context.trenzyColors.glassBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hexToColor(item.hex),
                                border: Border.all(
                                  color: name == 'White'
                                      ? context.trenzyColors.glassBorder
                                      : context.trenzyColors.background,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              name,
                              style: TextStyle(
                                color: isSelected
                                    ? context.trenzyColors.primaryFg
                                    : context.trenzyColors.mutedFg,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isSelected) ...[
                              SizedBox(width: 6),
                              Icon(
                                Icons.check,
                                size: 14,
                                color: context.trenzyColors.primaryFg,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 28),
                Text(
                  '${_selectedPriorities.length} of 3 selected',
                  style: TextStyle(
                    color: canContinue
                        ? context.trenzyColors.primary
                        : context.trenzyColors.mutedFg.withAlpha(128),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          // Pinned CTA — always reachable regardless of content height.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: GlowButton(
                  label: canContinue
                      ? 'FINISH'
                      : 'Select budget and priorities',
                  icon: Icons.auto_awesome_rounded,
                  enabled: canContinue,
                  onTap: canContinue ? _finishOnboarding : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
