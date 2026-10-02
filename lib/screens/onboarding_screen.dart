import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final _pages = [
    _OnboardingPageData(
      icon: Icons.auto_awesome_rounded,
      title: 'Discover Your Style',
      description: 'Trenzy uses AI to understand your unique fashion taste and recommend products you\'ll love.',
      gradient: [Color(0xFFF2CA50), Color(0xFFE0B840)],
    ),
    _OnboardingPageData(
      icon: Icons.groups_rounded,
      title: 'Shop Together',
      description: 'Create Blends with friends. Swipe, vote, and find the perfect picks as a group.',
      gradient: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    ),
    _OnboardingPageData(
      icon: Icons.psychology_rounded,
      title: 'Your AI Persona',
      description: 'Get a personalized style persona that evolves with your choices and preferences.',
      gradient: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
    ),
    _OnboardingPageData(
      icon: Icons.checkroom_rounded,
      title: 'Virtual Wardrobe',
      description: 'Organize your closet, build outfits, and never wonder what to wear again.',
      gradient: [Color(0xFFE74C3C), Color(0xFFC0392B)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Navigate to Question 1: Who do you shop for?
      context.go('${AppRoutes.favoriteCategories}?source=onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: () => context.go('${AppRoutes.favoriteCategories}?source=onboarding'),
                  child: Text(
                    'Skip',
                    style: GlassTypography.body(
                      color: context.trenzyColors.mutedFg,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with glow
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: page.gradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: page.gradient[0].withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: -8,
                              ),
                            ],
                          ),
                          child: Icon(
                            page.icon,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                        SizedBox(height: 40),
                        DisplayText(
                          page.title,
                          fontSize: 28,
                          weight: FontWeight.w800,
                        ),
                        SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? context.trenzyColors.primary
                              : context.trenzyColors.fg20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: GlowButton(
                      label: _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      height: 54,
                      onTap: _nextPage,
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
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
