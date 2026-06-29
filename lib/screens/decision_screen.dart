import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/decision_flow.dart';
import '../models/product_model.dart';
import '../router/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_widgets.dart';

/// Decision Screen - Uses ProductModel instead of SuggestionOption
class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({
    super.key,
    required this.onToggleTheme,
    required this.query,
    required this.selectedOptions,
    required this.reactions,
  });

  final VoidCallback onToggleTheme;
  final String query;
  final List<ProductModel> selectedOptions;
  final List<SocialReaction> reactions;

  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> {
  late final ProductModel _recommendation;
  late final int _socialApproval;

  String? _reasoning;
  bool _isLoadingReasoning = true;
  bool _isSaved = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _recommendation = _pickRecommendation();
    _socialApproval = _socialApprovalFor(_recommendation);
    _loadReasoningAndSave();
  }

  Future<void> _loadReasoningAndSave() async {
    final apiService = ref.read(apiServiceProvider);

    // Use product name and price for reasoning
    final reasoning = await apiService.getReasoning(
      query: widget.query,
      optionTitle: _recommendation.name,
      optionPrice: _recommendation.formattedPrice,
      aiScore: _calculateAiScore(_recommendation),
      socialApproval: _socialApproval,
    );

    if (mounted) {
      setState(() {
        _reasoning = reasoning.isNotEmpty ? reasoning : null;
        _isLoadingReasoning = false;
      });
    }

    // Persist the decision
    try {
      await apiService.saveDecision(
        query: widget.query,
        selectedOptions: widget.selectedOptions
            .map(
              (o) => {
                'id': o.id,
                'name': o.name,
                'price': o.price,
                'brand': o.brand,
                'rating': o.rating,
              },
            )
            .toList(),
        recommendedOptionId: _recommendation.id,
        socialApproval: _socialApproval,
        reasoning: reasoning,
      );
      if (mounted) setState(() => _isSaved = true);
    } catch (e) {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  /// Calculate AI score from rating (0-100)
  int _calculateAiScore(ProductModel product) {
    if (product.rating == null) return 70;
    return (product.rating! / 5 * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.verified_rounded,
              onLeadingPressed: () => context.pop(),
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Decision Ready',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Best match for "${widget.query}" based on AI score and social reactions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SuccessPulseBanner(
                    title: 'Good choice. You\'ll look great.',
                    message:
                        'Your final pick is ready, and room feedback has been folded in.',
                  ),
                  const SizedBox(height: 18),

                  _ProductHeroCard(
                    product: _recommendation,
                    matchScore: _calculateAiScore(_recommendation),
                    isRecommended: true,
                  ),
                  const SizedBox(height: 18),

                  /// Reasoning Card
                  _ReasoningCard(
                    isLoading: _isLoadingReasoning,
                    reasoning: _reasoning,
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          label: 'AI Score',
                          value: '${_calculateAiScore(_recommendation)}%',
                          tint: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'Social Approval',
                          value: '$_socialApproval%',
                          tint: context.successSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SaveStatusPill(
                          isSaved: _isSaved,
                          saveFailed: _saveFailed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Selected Options'),
                  const SizedBox(height: 12),
                  for (final option in widget.selectedOptions) ...[
                    _DecisionOptionTile(
                      option: option,
                      isRecommended: option.id == _recommendation.id,
                      socialApproval: _socialApprovalFor(option),
                      matchScore: _calculateAiScore(option),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: TapScale(
                      child: FilledButton(
                        onPressed: () => context.go(AppRoutes.home),
                        child: const Text('Start New Decision'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ProductModel _pickRecommendation() {
    return widget.selectedOptions.reduce((best, current) {
      final bestScore =
          _calculateAiScore(best) +
          widget.reactions.where((item) => item.optionId == best.id).length * 3;
      final currentScore =
          _calculateAiScore(current) +
          widget.reactions.where((item) => item.optionId == current.id).length *
              3;
      return currentScore > bestScore ? current : best;
    });
  }

  int _socialApprovalFor(ProductModel option) {
    if (widget.reactions.isEmpty) return 0;
    final totalVotes = widget.reactions
        .where((item) => item.optionId == option.id)
        .length;
    return ((totalVotes / widget.reactions.length) * 100).round();
  }
}

/// Product Hero Card
class _ProductHeroCard extends StatelessWidget {
  const _ProductHeroCard({
    required this.product,
    required this.matchScore,
    this.isRecommended = false,
  });

  final ProductModel product;
  final int matchScore;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isRecommended
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.cardColor,
        border: isRecommended
            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
            : null,
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 80,
              height: 80,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.shopping_bag_rounded),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.shopping_bag_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.brand != null && product.brand!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(product.brand!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      product.formattedPrice,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$matchScore% Match',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'BEST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reasoning Card
class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({required this.isLoading, required this.reasoning});

  final bool isLoading;
  final String? reasoning;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? primary.withValues(alpha: 0.10)
            : primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? primary.withValues(alpha: 0.22)
              : primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Why this is the best pick for you',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Analysing your decision...',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            )
          else if (reasoning != null && reasoning!.isNotEmpty)
            Text(
              reasoning!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.55),
            )
          else
            Text(
              'No reasoning available for this pick.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Decision option tile
class _DecisionOptionTile extends StatelessWidget {
  const _DecisionOptionTile({
    required this.option,
    required this.isRecommended,
    required this.socialApproval,
    required this.matchScore,
  });

  final ProductModel option;
  final bool isRecommended;
  final int socialApproval;
  final int matchScore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isRecommended
              ? Theme.of(context).colorScheme.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : context.cardStroke),
          width: isRecommended ? 1.5 : 1,
        ),
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 50,
              height: 50,
              child: option.imageUrl != null && option.imageUrl!.isNotEmpty
                  ? Image.network(
                      option.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.shopping_bag_rounded, size: 24),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.shopping_bag_rounded, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                if (option.brand != null && option.brand!.isNotEmpty)
                  Text(
                    option.brand!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                Text(
                  'AI $matchScore% | Social $socialApproval% | ${option.formattedPrice}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'BEST',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the actual save state: saving spinner, saved check, or failed warning.
class _SaveStatusPill extends StatelessWidget {
  const _SaveStatusPill({required this.isSaved, required this.saveFailed});

  final bool isSaved;
  final bool saveFailed;

  @override
  Widget build(BuildContext context) {
    if (isSaved) {
      return StatPill(
        label: 'Status',
        value: 'Saved',
        tint: context.successSurface,
      );
    }
    if (saveFailed) {
      return StatPill(
        label: 'Status',
        value: 'Save failed',
        tint: context.loveSurface,
      );
    }
    return StatPill(
      label: 'Status',
      value: 'Saving...',
      tint: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
  }
}
