import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/decision_flow.dart';
import '../models/product_model.dart';
import '../providers/suggestion_provider.dart';
import '../providers/analytics_service_provider.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({
    super.key,
    required this.onToggleTheme,
    required this.query,
  });

  final VoidCallback onToggleTheme;
  final String query;

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  final Set<String> _selectedOptionIds = <String>{};

  List<SuggestionOption> _getSelectedOptions(List<SuggestionOption> options) {
    return options
        .where((option) => _selectedOptionIds.contains(option.id))
        .toList();
  }

  void _toggleSelection(SuggestionOption option) {
    setState(() {
      if (_selectedOptionIds.contains(option.id)) {
        _selectedOptionIds.remove(option.id);
      } else {
        _selectedOptionIds.add(option.id);
      }
    });
  }

  // _openSocialRoom removed for beta — Social Rooms feature was scoped out.
  // To invite friends to weigh in, users should use Blend instead.

  void _openDecision(List<SuggestionOption> options) {
    final selectedOptions = _getSelectedOptions(options);
    if (selectedOptions.isEmpty) return;

    context.push(
      AppRoutes.decision,
      extra: DecisionRouteExtra(
        query: widget.query,
        selectedOptions: selectedOptions,
        reactions: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSuggestions = ref.watch(suggestionsProvider(widget.query));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.notifications_none_rounded,
              onLeadingPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      _pill('AI Curated for You', context.successSurface),
                      const SizedBox(width: 8),
                      _pill(
                        widget.query,
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Style AI Suggestions',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Suggestions generated for "${widget.query}". Select one or more options to continue.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 18),
                  asyncSuggestions.when(
                    loading: () => const SuggestionLoadingState(),
                    error: (err, stack) => Column(
                      children: [
                        const SizedBox(height: 72),
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load suggestions',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friendlyErrorMessage(err),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(suggestionsProvider(widget.query)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    data: (options) {
                      if (options.isEmpty) {
                        return const FriendlyEmptyState(
                          title: 'No looks yet',
                          message:
                              'Try a different vibe or add a little more detail so we can curate better options for you.',
                          icon: Icons.checkroom_rounded,
                        );
                      }

                      final selectedOptions = _getSelectedOptions(options);
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < options.length;
                            index++
                          ) ...[
                            _ProductSuggestionCard(
                              product: options[index].product,
                              matchScore: options[index].matchScore,
                              isSelected: _selectedOptionIds.contains(
                                options[index].id,
                              ),
                              onTap: () {
                                _toggleSelection(options[index]);
                                // Track recommendation click analytics
                                ref
                                    .read(analyticsServiceProvider)
                                    .logEvent(
                                      name: 'recommendation_click',
                                      parameters: {
                                        'product_id': options[index].product.id,
                                        'query': widget.query,
                                        'match_score':
                                            options[index].matchScore,
                                      },
                                    );
                              },
                              compact: index == 1,
                            ),
                            const SizedBox(height: 14),
                          ],
                          // "Ask Friends" / Social Room button removed for beta
                          // — Social Rooms feature was scoped out by founder.
                          SizedBox(
                            width: double.infinity,
                            child: TapScale(
                              child: FilledButton(
                                onPressed: selectedOptions.isEmpty
                                    ? null
                                    : () => _openDecision(options),
                                child: const Text('Continue'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.18) : color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _ProductSuggestionCard extends StatelessWidget {
  const _ProductSuggestionCard({
    required this.product,
    required this.matchScore,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final ProductModel product;
  final int matchScore;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedScale(
      scale: isSelected ? 1.01 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? primary
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : context.cardStroke),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.28
                    : 0.07,
              ),
              blurRadius: Theme.of(context).brightness == Brightness.dark
                  ? 34
                  : 24,
              offset: const Offset(0, 14),
            ),
            if (isSelected)
              BoxShadow(
                color: primary.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: compact ? 165 : 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.shopping_bag_rounded,
                              size: 60,
                            ),
                          )
                        : const Icon(Icons.shopping_bag_rounded, size: 60),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'AI CURATED',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.94)
                            : Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$matchScore% Match',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  product.formattedPrice,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              product.brand ?? product.articleType ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    'Selected for comparison',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TapScale(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: isSelected ? primary : null,
                  ),
                  child: Text(isSelected ? 'Selected ✓' : 'Select Option'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
