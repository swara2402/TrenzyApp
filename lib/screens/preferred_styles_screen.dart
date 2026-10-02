import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class PreferredStylesScreen extends ConsumerStatefulWidget {
  const PreferredStylesScreen({super.key});

  @override
  ConsumerState<PreferredStylesScreen> createState() =>
      _PreferredStylesScreenState();
}

class _PreferredStylesScreenState extends ConsumerState<PreferredStylesScreen> {
  final List<String> selectedStyles = [];

  bool get canContinue => selectedStyles.length <= 5; // Allow 0-5 styles (no minimum requirement)

  @override
  void initState() {
    super.initState();
    _restoreFromProvider();
  }

  void _restoreFromProvider() {
    final saved = ref.read(userPreferencesProvider).preferredStyles;
    if (saved.isNotEmpty) {
      selectedStyles.addAll(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stylesAsync = ref.watch(personaStylesProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => context.go(AppRoutes.favoriteCategories),
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
                    value: 2 / 3,
                    backgroundColor: Colors.grey[800],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(context.trenzyColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Step 2 of 3',
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
              'What styles feel most like you?',
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pick styles that match your vibe (optional).',
              style: TextStyle(
                color: context.trenzyColors.mutedFg.withAlpha(179),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: stylesAsync.when(
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildErrorState(error),
                data: (styles) {
                  if (styles.isEmpty) {
                    return _buildErrorState('No styles available');
                  }
                  return _buildStyleGrid(styles);
                },
              ),
            ),
            SizedBox(height: 24),
            Text(
              '${selectedStyles.length} selected',
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
                          context.go(AppRoutes.shoppingPriorities);
                        }
                      }
                    : null,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  // Skip and continue to next step
                  if (context.mounted) {
                    context.go(AppRoutes.shoppingPriorities);
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

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: context.trenzyColors.mutedFg.withAlpha(128)),
            SizedBox(height: 16),
            Text(
              'Could not load styles',
              style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: TextStyle(color: context.trenzyColors.mutedFg.withAlpha(150), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            GlowButton(
              label: 'Retry',
              onTap: () => ref.invalidate(personaStylesProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleGrid(List<String> styles) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: styles.map((style) {
        final isSelected = selectedStyles.contains(style);
        return ChoiceChip(
          label: Text(style),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                if (selectedStyles.length < 5) {
                  selectedStyles.add(style);
                }
              } else {
                selectedStyles.remove(style);
              }
            });
            ref
                .read(userPreferencesProvider.notifier)
                .setStyles(selectedStyles);
          },
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
    );
  }
}