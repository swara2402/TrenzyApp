import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/router/app_router.dart';

class PreferredStylesScreen extends ConsumerStatefulWidget {
  const PreferredStylesScreen({super.key});

  @override
  ConsumerState<PreferredStylesScreen> createState() =>
      _PreferredStylesScreenState();
}

class _PreferredStylesScreenState extends ConsumerState<PreferredStylesScreen> {
  static const Color _cream = Color(0xFFFFFAF6);
  static const Color _rose = Color(0xFFD98F7B);
  static const Color _roseDeep = Color(0xFFB96F5A);
  static const Color _rosePale = Color(0xFFFFEEE7);
  static const Color _ink = Color(0xFF35231F);
  static const Color _muted = Color(0xFF8B746C);
  static const Color _line = Color(0xFFF0DED5);

  final List<String> selectedStyles = [];
  bool _isSaving = false;

  bool get canContinue => selectedStyles.length <= 5;

  static const Map<String, IconData> _styleIcons = {
    'Casual': Icons.checkroom_rounded,
    'Formal': Icons.business_center_rounded,
    'Streetwear': Icons.directions_run_rounded,
    'Minimalist': Icons.dry_cleaning_rounded,
    'Classic': Icons.watch_outlined,
    'Bohemian': Icons.spa_outlined,
    'Sporty': Icons.fitness_center_rounded,
    'Ethnic': Icons.auto_awesome_outlined,
    'Preppy': Icons.school_outlined,
    'Grunge': Icons.bolt_rounded,
  };

  Future<void> _continueToDiscovery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(apiServiceProvider).savePreferences(
            preferredStyles: selectedStyles,
            onboardingStep: 3,
          );
      if (mounted) context.go(AppRoutes.discoveryPreferences);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save your progress. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _continueToDiscovery,
          ),
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    selectedStyles.addAll(ref.read(userPreferencesProvider).preferredStyles);
  }

  @override
  Widget build(BuildContext context) {
    final stylesAsync = ref.watch(personaStylesProvider);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 27),
          onPressed: () => context.go(AppRoutes.favoriteCategories),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 2, 28, 12),
            child: Column(
              children: [
                Row(
                  children: List.generate(3, (index) {
                    final complete = index < 2;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
                        decoration: BoxDecoration(
                          color: complete ? _rose : _line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 9),
                const Text(
                  'STEP 2 OF 3',
                  style: TextStyle(
                    color: _roseDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What styles feel\nmost like you?',
                            style: TextStyle(
                              color: _ink,
                              fontSize: width < 370 ? 31 : 36,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: _muted,
                                fontSize: 15,
                                height: 1.45,
                              ),
                              children: [
                                TextSpan(text: 'Pick styles that match your vibe '),
                                TextSpan(
                                  text: '(optional)',
                                  style: TextStyle(
                                    color: _roseDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: _roseDeep,
                                  size: 18,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Choose up to 5 — you can change these anytime.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: width < 370 ? 11 : 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  stylesAsync.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: _rose),
                      ),
                    ),
                    error: (error, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorState(error),
                    ),
                    data: (styles) {
                      if (styles.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildErrorState('No styles available'),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: width < 355 ? 1 : 2,
                            crossAxisSpacing: 11,
                            mainAxisSpacing: 11,
                            mainAxisExtent: 82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildStyleCard(styles[index]),
                            childCount: styles.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 13, 22, 10),
              decoration: BoxDecoration(
                color: _cream.withValues(alpha: 0.97),
                border: const Border(top: BorderSide(color: _line, width: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: _roseDeep.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: _roseDeep,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${selectedStyles.length} selected',
                          style: const TextStyle(
                            color: _roseDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (selectedStyles.length == 5)
                          const Text(
                            'Maximum reached',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_rose, _roseDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _roseDeep.withValues(alpha: 0.24),
                              blurRadius: 15,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving || !canContinue
                              ? null
                              : _continueToDiscovery,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: _line,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'CONTINUE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        letterSpacing: 1.7,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextButton(
                      onPressed: _isSaving ? null : _continueToDiscovery,
                      style: TextButton.styleFrom(
                        foregroundColor: _roseDeep,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _rose,
                          decorationThickness: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleCard(String style) {
    final isSelected = selectedStyles.contains(style);
    final icon = _styleIcons[style] ?? Icons.checkroom_rounded;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$style style',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedStyles.remove(style);
              } else if (selectedStyles.length < 5) {
                selectedStyles.add(style);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Choose up to 5 styles. Remove one to add another.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
            ref.read(userPreferencesProvider.notifier).setStyles(
                  List<String>.from(selectedStyles),
                );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF0E9) : Colors.white,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: isSelected ? _rose : _line,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _roseDeep.withValues(alpha: isSelected ? 0.10 : 0.035),
                  blurRadius: isSelected ? 13 : 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFFFDED2) : _rosePale,
                  ),
                  child: Icon(icon, color: _roseDeep, size: 24),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    style,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 190),
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _rose : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _rose : const Color(0xFFD9BEB3),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: _rosePale,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: _roseDeep,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Could not load styles',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Check your connection and try again.',
              style: TextStyle(color: _muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => ref.invalidate(personaStylesProvider),
              style: OutlinedButton.styleFrom(
                foregroundColor: _roseDeep,
                side: const BorderSide(color: _rose),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
