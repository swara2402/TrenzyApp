import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

/// Lets returning users adjust the style choices that personalize Trenzy.
class StylePreferencesEditScreen extends ConsumerStatefulWidget {
  const StylePreferencesEditScreen({super.key});

  @override
  ConsumerState<StylePreferencesEditScreen> createState() =>
      _StylePreferencesEditScreenState();
}

class _StylePreferencesEditScreenState
    extends ConsumerState<StylePreferencesEditScreen> {
  static const _styleOptions = [
    'Casual', 'Formal', 'Streetwear', 'Minimalist', 'Classic',
    'Bohemian', 'Sporty', 'Ethnic', 'Preppy', 'Grunge',
  ];
  static const _aestheticOptions = [
    'Old Money', 'Clean Girl', 'Quiet Luxury', 'Y2K', 'Coquette',
    'Minimalist', 'Street Style', 'Soft Girl', 'Dark Academia',
    'Cottagecore', 'Vintage', 'Athleisure',
  ];
  static const _categories = [
    'Tops', 'Bottoms', 'Dresses', 'Shoes', 'Bags', 'Accessories',
    'Ethnic Wear', 'Outerwear',
  ];
  static const _colors = [
    'Black', 'White', 'Beige', 'Brown', 'Blue', 'Pink', 'Red',
    'Green', 'Grey', 'Purple',
  ];

  late List<String> _styles;
  late List<String> _aesthetics;
  late List<String> _categoriesSelected;
  late List<String> _colorsSelected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(userPreferencesProvider);
    _styles = [...prefs.preferredStyles];
    _aesthetics = [...prefs.preferredAesthetics];
    _categoriesSelected = [...prefs.preferredCategories];
    _colorsSelected = [...prefs.preferredColors];
  }

  Widget _choiceSection(String title, String subtitle, List<String> options,
      List<String> selected, IconData icon) {
    final colors = context.trenzyColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: colors.primary, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(
              color: colors.foreground, fontSize: 17,
              fontWeight: FontWeight.w800,
            ))),
            Text('${selected.length}', style: TextStyle(
              color: colors.primary, fontSize: 12, fontWeight: FontWeight.w800,
            )),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(
            color: colors.mutedFg, fontSize: 12,
          )),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (isSelected) {
                      selected.remove(option);
                    } else {
                      selected.add(option);
                    }
                  });
                  final notifier = ref.read(userPreferencesProvider.notifier);
                  notifier.setStyles(List.of(_styles));
                  notifier.setAesthetics(List.of(_aesthetics));
                  notifier.setCategories(List.of(_categoriesSelected));
                  notifier.setColors(List.of(_colorsSelected));
                },
                showCheckmark: true,
                selectedColor: colors.primary.withValues(alpha: 0.20),
                backgroundColor: colors.graphite,
                side: BorderSide(color: isSelected
                    ? colors.primary : colors.glassBorder),
                labelStyle: TextStyle(
                  color: isSelected ? colors.primary : colors.foreground,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.savePreferences(
        preferredStyles: _styles,
        preferredAesthetics: _aesthetics,
        preferredCategories: _categoriesSelected,
        preferredColors: _colorsSelected,
      );
      if (!mounted) return;
      ref.invalidate(personaProvider);
      ref.invalidate(serverPreferencesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your style preferences are updated ✨')),
      );
      context.go(AppRoutes.home);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your style preferences. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text('Your Style Persona'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.12), colors.graphite,
                ],
              ),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Choose what feels like you. These choices help shape your feed and recommendations, and you can change them anytime.',
                style: TextStyle(color: colors.foreground, height: 1.4, fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 24),
          _choiceSection('Your styles', 'Everyday looks you gravitate towards',
              _styleOptions, _styles, Icons.checkroom_rounded),
          _choiceSection('Aesthetics', 'The visual vibes you love',
              _aestheticOptions, _aesthetics, Icons.auto_awesome_rounded),
          _choiceSection('Categories', 'What you want to shop for',
              _categories, _categoriesSelected, Icons.category_outlined),
          _choiceSection('Favourite colours', 'Colours you want to see more often',
              _colors, _colorsSelected, Icons.palette_outlined),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: GlassGradients.primary,
                borderRadius: BorderRadius.circular(17),
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('SAVE MY STYLE',
                        style: TextStyle(fontWeight: FontWeight.w800,
                          letterSpacing: 1.1, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
