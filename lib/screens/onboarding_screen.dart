import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _fashionFocus;
  bool _isSavingFocus = false;

  static const _rose = Color(0xFFD79D8A);
  static const _roseLight = Color(0xFFE2A997);

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.auto_awesome_rounded,
      title: 'Discover Your Style',
      description: 'Get fashion inspiration and product recommendations shaped around your taste.',
    ),
    _OnboardingPageData(
      icon: Icons.groups_rounded,
      title: 'Style Together',
      description: 'Create Blends with friends, share picks, and decide on looks together.',
    ),
    _OnboardingPageData(
      icon: Icons.psychology_rounded,
      title: 'Meet Your AI Stylist',
      description: 'Build a style persona that learns from the preferences you choose.',
    ),
    _OnboardingPageData(
      icon: Icons.checkroom_rounded,
      title: 'Make Your Wardrobe Work',
      description: 'Organize your closet and find new ways to put outfits together.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // The first page collects a fashion preference before the intro slides.
    if (_currentPage == 0) {
      if (_fashionFocus != null) {
        setState(() => _isSavingFocus = true);
        try {
          final existing = ref.read(userPreferencesProvider).preferredAesthetics;
          final updated = existing
              .where((value) => !value.startsWith('Audience: '))
              .toList()
            ..add('Audience: $_fashionFocus');
          await ref.read(apiServiceProvider).savePreferences(
                preferredAesthetics: updated,
              );
          ref.read(userPreferencesProvider.notifier).setAesthetics(updated);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not save this preference. You can continue and change it later.'),
              backgroundColor: context.trenzyColors.graphite,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } finally {
          if (mounted) setState(() => _isSavingFocus = false);
        }
      }
      if (!mounted) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (_currentPage < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToPreferences();
    }
  }

  void _goToPreferences() {
    context.go('${AppRoutes.favoriteCategories}?source=onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    final totalPages = _pages.length + 1;
    final isFocusPage = _currentPage == 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Trenzy',
                    style: TextStyle(
                      fontFamily: GlassTypography.bodyFont,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: Color(0xFFFAF6F0),
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _rose),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSavingFocus ? null : _goToPreferences,
                    child: Text(
                      'Skip',
                      style: GlassTypography.body(color: colors.mutedFg, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildFashionFocus(context);
                  final page = _pages[index - 1];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_roseLight, _rose]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _rose.withValues(alpha: 0.22), blurRadius: 34, spreadRadius: -6),
                            ],
                          ),
                          child: Icon(page.icon, color: colors.primaryFg, size: 48),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: GlassTypography.display(color: colors.foreground, fontSize: 29, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: GlassTypography.body(color: colors.mutedFg, fontSize: 15, height: 1.6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPages, (index) {
                      final active = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? colors.primary : colors.fg20,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: GlowButton(
                      label: _isSavingFocus
                          ? 'SAVING...'
                          : (isFocusPage
                              ? 'Personalize My Feed'
                              : (_currentPage == totalPages - 1 ? 'Get Started' : 'Next')),
                      onTap: _isSavingFocus ? null : _continue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFashionFocus(BuildContext context) {
    final colors = context.trenzyColors;
    final width = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _rose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _rose.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.tune_rounded, color: _rose, size: 25),
          ),
          const SizedBox(height: 24),
          Text(
            'What fashion should we focus on?',
            style: GlassTypography.display(
              color: colors.foreground,
              fontSize: width < 370 ? 29 : 33,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We’ll use this as a starting point for your feed. You can explore everything and change your preferences anytime.',
            style: GlassTypography.body(color: colors.mutedFg, fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 24),
          _focusOption(context, value: 'Menswear', title: 'Men’s fashion', subtitle: 'Menswear, fits and outfit ideas', icon: Icons.checkroom_rounded),
          const SizedBox(height: 12),
          _focusOption(context, value: 'Womenswear', title: 'Women’s fashion', subtitle: 'Womenswear, looks and outfit ideas', icon: Icons.style_rounded),
          const SizedBox(height: 12),
          _focusOption(context, value: 'All fashion', title: 'Both / unisex', subtitle: 'Explore across fashion categories', icon: Icons.diversity_3_rounded),
          const SizedBox(height: 12),
          _focusOption(context, value: 'Personalize later', title: 'I’ll decide later', subtitle: 'Start broad and personalize as I go', icon: Icons.explore_rounded),
        ],
      ),
    );
  }

  Widget _focusOption(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final colors = context.trenzyColors;
    final selected = _fashionFocus == value;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _fashionFocus = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected ? _rose.withValues(alpha: 0.14) : colors.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _rose : colors.glassBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _rose.withValues(alpha: selected ? 0.22 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: _roseLight, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GlassTypography.body(color: colors.foreground, fontSize: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: GlassTypography.body(color: colors.mutedFg, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? _roseLight : colors.mutedFg,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
