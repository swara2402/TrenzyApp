import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/services/api_service.dart';
import 'package:trenzy/providers/api_service_provider.dart';

class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({
    super.key,
    this.query,
    this.selectedOptions,
  });

  final String? query;
  final List<ProductModel>? selectedOptions;

  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> {
  int? _selectedIndex;
  String? _reasoning;
  bool _isSaving = false;
  bool _isGeneratingReasoning = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.selectedOptions ?? [];

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassBackButton(
                    onTap: () => context.go(AppRoutes.home),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DECIDE',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: context.trenzyColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.query ?? 'Make a Decision',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.trenzyColors.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? _buildEmptyState()
                  : _buildComparisonList(options),
            ),
            if (_reasoning != null) _buildReasoningBar(),
            if (_selectedIndex != null) _buildSaveBar(options),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassColors.glass,
                border: Border.all(color: GlassColors.glassBorder),
              ),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: 36,
                color: GlassColors.primary,
              ),
            ),
            SizedBox(height: 20),
            DisplayText(
              'No options to compare',
              fontSize: 18,
              weight: FontWeight.w700,
            ),
            SizedBox(height: 8),
            Text(
              'Add items to your blend to start comparing.',
              style: GlassTypography.body(
                color: GlassColors.mutedFg,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonList(List<ProductModel> options) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final product = options[index];
        final isSelected = _selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DecisionCard(
            product: product,
            index: index,
            isSelected: isSelected,
            onTap: () => _selectOption(index, product),
          ),
        );
      },
    );
  }

  Future<void> _selectOption(int index, ProductModel product) async {
    setState(() {
      _selectedIndex = index;
      _reasoning = null;
    });

    // Get reasoning from backend
    setState(() => _isGeneratingReasoning = true);
    try {
      final api = ref.read(apiServiceProvider);
      final reasoning = await api.getReasoning(
        query: widget.query ?? '',
        optionTitle: product.name,
        optionPrice: product.effectivePrice,
        aiScore: index,
        socialApproval: 0,
      );
      if (mounted) {
        setState(() => _reasoning = reasoning);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _reasoning = 'This option matches your style preferences.');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReasoning = false);
    }
  }

  Widget _buildReasoningBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.trenzyColors.primary.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(
            color: context.trenzyColors.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_isGeneratingReasoning)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.trenzyColors.primary,
              ),
            )
          else
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: context.trenzyColors.primary,
            ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _reasoning ?? '',
              style: GlassTypography.body(
                color: context.trenzyColors.foreground,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(List<ProductModel> options) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.trenzyColors.glassDock,
        border: Border(
          top: BorderSide(color: context.trenzyColors.glassBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveDecision,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.trenzyColors.primary,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.trenzyColors.primaryFg,
                  ),
                )
              : Text(
                  'Confirm Choice',
                  style: TextStyle(
                    color: context.trenzyColors.primaryFg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _saveDecision() async {
    final options = widget.selectedOptions ?? [];
    if (_selectedIndex == null || _selectedIndex! >= options.length) return;

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final selectedProduct = options[_selectedIndex!];

      await api.saveDecision(
        query: widget.query ?? '',
        selectedOptions: options
            .map((p) => {'id': p.id, 'title': p.name, 'price': p.effectivePrice})
            .toList(),
        recommendedOptionId: selectedProduct.id,
        socialApproval: 0,
        reasoning: _reasoning ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decision saved')),
        );
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DecisionCard extends StatelessWidget {
  final ProductModel product;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _DecisionCard({
    required this.product,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        color: context.trenzyColors.graphite,
        radius: 20,
        padding: const EdgeInsets.all(12),
        borderColor: isSelected
            ? context.trenzyColors.primary.withValues(alpha: 0.3)
            : context.trenzyColors.glassBorder,
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ApiService.resolveImageUrl(product.imageUrl!) ?? '',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 80,
                            height: 80,
                            color: context.trenzyColors.graphite,
                            child: Icon(Icons.image_outlined, color: context.trenzyColors.fg20, size: 24),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 80,
                            height: 80,
                            color: context.trenzyColors.graphite,
                            child: Icon(Icons.broken_image, color: context.trenzyColors.fg20, size: 24),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: context.trenzyColors.graphite,
                          child: Icon(Icons.shopping_bag_outlined, color: context.trenzyColors.fg20, size: 24),
                        ),
                ),
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? context.trenzyColors.primary : context.trenzyColors.glass,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? context.trenzyColors.primary : context.trenzyColors.glassBorder,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: context.trenzyColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? context.trenzyColors.primaryFg : context.trenzyColors.mutedFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(
                      product.brand!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                  if (product.brand != null) SizedBox(height: 3),
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.trenzyColors.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: isSelected ? GlassGradients.primary : null,
                          color: isSelected ? null : context.trenzyColors.glass,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? null : Border.all(color: context.trenzyColors.glassBorder),
                        ),
                        child: Text(
                          product.effectivePrice,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? context.trenzyColors.primaryFg : context.trenzyColors.primary,
                          ),
                        ),
                      ),
                      if (product.rating != null) ...[
                        SizedBox(width: 8),
                        Icon(Icons.star_rounded, size: 14, color: context.trenzyColors.primary),
                        SizedBox(width: 2),
                        Text(
                          product.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.trenzyColors.primary.withValues(alpha: 0.15)
                    : context.trenzyColors.glass,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.trenzyColors.primary.withValues(alpha: 0.4)
                      : context.trenzyColors.glassBorder,
                ),
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: isSelected ? context.trenzyColors.primary : context.trenzyColors.fg40,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
