import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

final _productCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getPersonaProductTypes();
  } catch (_) {
    return ['Upper', 'Bottom', 'Footwear'];
  }
});

class FavoriteCategoriesScreen extends ConsumerStatefulWidget {
  const FavoriteCategoriesScreen({super.key});

  @override
  ConsumerState<FavoriteCategoriesScreen> createState() =>
      _FavoriteCategoriesScreenState();
}

class _FavoriteCategoriesScreenState
    extends ConsumerState<FavoriteCategoriesScreen> {
  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _restoreFromProvider();
  }

  void _restoreFromProvider() {
    final saved = ref.read(userPreferencesProvider).preferredCategories;
    if (saved.isNotEmpty) {
      _selectedCategories.addAll(saved);
    }
  }

  void _toggleSelection(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    ref.read(userPreferencesProvider.notifier).setCategories(_selectedCategories);
  }

  bool get canContinue => _selectedCategories.isNotEmpty;

  void _onBack() {
    final source = GoRouterState.of(context).uri.queryParameters['source'] ?? 'onboarding';
    if (source == 'signup') {
      // If coming from signup, go back to sign-up screen instead of login
      context.go(AppRoutes.signUp);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: _onBack,
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
                    value: 1 / 3, // Step 1 of 3
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(context.trenzyColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Step 1 of 3',
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What product categories interest you?',
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select product categories you love to shop for.',
              style: TextStyle(
                color: context.trenzyColors.mutedFg.withAlpha(179),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            Expanded(
              child: _CategoriesList(
                selectedCategories: _selectedCategories,
                onToggle: _toggleSelection,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: 'CONTINUE',
                onTap: () { // Remove canContinue check to always allow continuing
                  if (context.mounted) {
                    context.go(AppRoutes.preferredStyles);
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  // Skip and continue to next step
                  if (context.mounted) {
                    context.go(AppRoutes.preferredStyles);
                  }
                },
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CategoriesList extends ConsumerWidget {
  final List<String> selectedCategories;
  final Function(String) onToggle;

  const _CategoriesList({
    required this.selectedCategories,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_productCategoriesProvider);

    return categoriesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.trenzyColors.primary),
      ),
      error: (_, _) => Center(
        child: Text(
          'Could not load categories',
          style: TextStyle(color: context.trenzyColors.mutedFg),
        ),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Text(
              'No categories available',
              style: TextStyle(color: context.trenzyColors.mutedFg),
            ),
          );
        }
        return ListView(
          children: categories.map((category) {
            final isSelected = selectedCategories.contains(category);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedScale(
                scale: isSelected ? 1.02 : 1.0,
                duration: Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: () => onToggle(category),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
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
                                color: context.trenzyColors.primary.withAlpha(77),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? context.trenzyColors.primaryFg
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? context.trenzyColors.primaryFg
                                  : context.trenzyColors.mutedFg.withAlpha(128),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: context.trenzyColors.primary,
                                )
                              : null,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? context.trenzyColors.primaryFg
                                  : context.trenzyColors.mutedFg,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}