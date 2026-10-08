import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trenzy/widgets/section_states.dart';
import 'package:trenzy/models/wardrobe_model.dart';
import 'package:trenzy/theme/trenzy_colors.dart';

class StylePersonaScreen extends ConsumerStatefulWidget {
  const StylePersonaScreen({super.key});

  @override
  ConsumerState<StylePersonaScreen> createState() => _StylePersonaScreenState();
}

class _StylePersonaScreenState extends ConsumerState<StylePersonaScreen> {
  bool _generatedOnce = false;
  bool _isSaving = false;

  Future<void> _ensurePersona() async {
    if (_generatedOnce) return;
    _generatedOnce = true;

    try {
      // Convert preferences to snake_case to match API expectations
      final preferences = <String, dynamic>{
        'preferred_categories': ref.read(userPreferencesProvider).preferredCategories,
        'preferred_brands': ref.read(userPreferencesProvider).preferredBrands,
        'preferred_colors': ref.read(userPreferencesProvider).preferredColors,
        'preferred_styles': ref.read(userPreferencesProvider).preferredStyles,
        'preferred_aesthetics': ref.read(userPreferencesProvider).preferredAesthetics,
        'preferred_seasons': ref.read(userPreferencesProvider).preferredSeasons,
        'preferred_occasions': ref.read(userPreferencesProvider).preferredOccasions,
        'budget_max': ref.read(userPreferencesProvider).budgetMax,
        'discover_preferences': ref.read(userPreferencesProvider).discoverPreferences,
        'product_interests': ref.read(userPreferencesProvider).productInterests,
      };
      await ref.read(apiServiceProvider).generatePersona(preferences: preferences);
      // Refresh persona provider after generation
      ref.invalidate(personaProvider);
    } catch (e) {
      // Non-blocking: persona generation failure shouldn't block the user
    }
  }

  @override
  void initState() {
    super.initState();
    // Generate persona if needed when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(personaProvider).maybeWhen(
        data: (StylePersona? persona) {
          if ((persona == null || persona.id == 0) && !_generatedOnce) {
            _ensurePersona();
          }
        },
        orElse: () {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    // Listen to persona changes to trigger regeneration if needed
    ref.listen(personaProvider, (prev, next) {
      next.whenOrNull(data: (StylePersona? persona) {
        if ((persona == null || persona.id == 0) && !_generatedOnce) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePersona());
        }
      });
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _StylePersonaAppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _PersonaHeroCard(
            onRefine: () {
              _generatedOnce = false;
              // Fire-and-forget; state/provider refresh will happen after generation.
              _ensurePersona();
            },
          ),

          const SizedBox(height: 24),
          const _DnaAndColorGrid(),
          const SizedBox(height: 48),
          const _BrandLogoCloud(),
          const SizedBox(height: 48),
          const _StyleEvolutionTimeline(),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _buildContinueButton(),
    );
  }

  Widget _buildContinueButton() {
    final colors = context.trenzyColors;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: _isSaving ? null : () async {
          setState(() => _isSaving = true);
          try {
            final prefs = ref.read(userPreferencesProvider);
            await ref.read(apiServiceProvider).savePreferences(
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
            );
            if (!mounted) return;
            context.go(AppRoutes.home);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save preferences, continuing anyway')),
              );
              context.go(AppRoutes.home);
            }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryFg,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        child: _isSaving 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF241A00)),
              )
            : const Text('CONTINUE'),
      ),
    );
  }
}

class _StylePersonaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StylePersonaAppBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          backgroundColor: colors.background.withValues(alpha: 0.8),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colors.graphite,
              child: Text('U', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          title: const Text(
            'Trenzy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: -0.5,
              color: Color(0xFFF2CA50),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'AI Stylist',
              icon: const Icon(Icons.auto_awesome, color: Color(0xFFEAE1D4)),
              onPressed: () => context.push(AppRoutes.aiStylist),
            ),
            IconButton(
              tooltip: 'Style DNA',
              icon: const Icon(Icons.insights_outlined, color: Color(0xFFEAE1D4)),
              onPressed: () => context.push(AppRoutes.aiStyleDna),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFFEAE1D4)),
              onPressed: () => context.push(AppRoutes.notifications),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Colors.white.withValues(alpha: 0.05),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: const BoxDecoration(
            color: Color(0x66231F17),
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ).copyWith(
            border: Border.all(color: Color(0x0DFFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PersonaHeroCard extends ConsumerWidget {
  const _PersonaHeroCard({required this.onRefine});

  final VoidCallback onRefine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    final personaAsync = ref.watch(personaProvider);

    return personaAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF2CA50)),
      ),
      error: (_, _) => const Text(
        'Could not load persona',
        style: TextStyle(color: Colors.white),
      ),
      data: (StylePersona? persona) {
        if (persona == null) return const SizedBox.shrink();

        return _GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'https://placehold.co/400x500/1a1a2e/666.png?text=${Uri.encodeComponent(persona.name)}',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'PRIMARY PERSONA',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                persona.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEAE1D4),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                persona.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFD0C5AF),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      onRefine();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refining your style DNA...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: const Color(0xFF241A00),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    child: const Text('REFINE DNA'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'My Trenzy style persona: ${persona.name}\n'
                              '${persona.description}\n'
                              'Shared from Trenzy',
                          subject: 'My Trenzy style persona',
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEAE1D4),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      side: BorderSide(color: const Color(0xFF99907C).withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    child: const Text('SHARE'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


class _DnaAndColorGrid extends ConsumerWidget {
  const _DnaAndColorGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    final personaAsync = ref.watch(personaProvider);
    return personaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF2CA50))),
      error: (_, _) => ErrorSection(
        title: 'Couldn\u2019t load your style DNA',
        message: 'Something went wrong loading your persona. Please try again.',
        onRetry: () => ref.invalidate(personaProvider),
      ),
      data: (StylePersona? persona) {
        if (persona == null) return const SizedBox.shrink();
        return _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR STYLE DNA',
                style: TextStyle(
                  color: Color(0xFFF2CA50),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: persona.keywords.map((keyword) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.graphite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    keyword,
                    style: const TextStyle(color: Color(0xFFEAE1D4), fontSize: 14),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 32),
              if (persona.colorPalette.isNotEmpty) ...[
                const Text(
                  'YOUR COLOR PALETTE',
                  style: TextStyle(
                    color: Color(0xFFF2CA50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: persona.colorPalette.map((colorHex) => Expanded(
                    child: Container(
                      height: 48,
                      color: Color(int.parse(colorHex.replaceFirst('#', '0xFF'))),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BrandLogoCloud extends ConsumerWidget {
  const _BrandLogoCloud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR PREFERRED BRANDS',
            style: TextStyle(
              color: Color(0xFFF2CA50),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          if (prefs.preferredBrands.isEmpty)
            const Text(
              'No brands selected yet. Your persona will curate brands matching your style.',
              style: TextStyle(color: Color(0xFFD0C5AF), fontSize: 14),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prefs.preferredBrands.map((brand) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2A21),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  brand,
                  style: const TextStyle(color: Color(0xFFEAE1D4), fontSize: 14),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class _StyleEvolutionTimeline extends ConsumerWidget {
  const _StyleEvolutionTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STYLE EVOLUTION ROADMAP',
            style: TextStyle(
              color: Color(0xFFF2CA50),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _buildTimelineItem('Current', 'Established your core style identity', true, colors),
          _buildTimelineItem('Next', 'Discover new aesthetics matching your taste', false, colors),
          _buildTimelineItem('Future', 'Curate a fully personalized wardrobe', false, colors),
          const SizedBox(height: 16),
          const Text(
            'Your app will continuously learn from your interactions to refine recommendations and keep your style persona updated. The home feed, discover page, and wardrobe suggestions will all be personalized based on your persona.',
            style: TextStyle(color: Color(0xFFD0C5AF), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String description, bool isActive, TrenzyColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? colors.primary : colors.graphite,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isActive ? colors.primary : colors.mutedFg,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isActive ? colors.mutedFg : colors.fg70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}