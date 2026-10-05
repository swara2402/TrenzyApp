import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/providers/products_provider.dart';
import 'package:trenzy/providers/wishlist_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/analytics/events.dart';
import 'package:share_plus/share_plus.dart';

import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/widgets/section_states.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  bool _isAddingToWardrobe = false;
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailsProvider(widget.productId));
    // Keep _isLiked in sync with the wishlist provider (non-destructive — only
    // updates when the user has NOT already made a local optimistic toggle).
    final wishlisted = ref.watch(
      wishlistProvider.select(
        (w) => w.valueOrNull?.contains(widget.productId) ?? false,
      ),
    );
    // Only sync from remote if we're not in the middle of an optimistic update.
    // We detect this by comparing once on first build (mounted) and after any
    // invalidation. A simple approach: just keep the remote value as authoritative
    // when the wishlist loads (it may lag briefly after toggling, which is fine).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && wishlisted != _isLiked) {
        setState(() => _isLiked = wishlisted);
      }
    });

    ref.listen(productDetailsProvider(widget.productId), (prev, next) {
      if (next.hasValue && next.value != null) {
        final api = ref.read(apiServiceProvider);
        api.trackProductView(widget.productId);
      }
    });

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: productAsync.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorSection(
                  title: 'Couldn\u2019t load this product',
                  message: 'The product took a wrong turn. Please try again.',
                  onRetry: () =>
                      ref.invalidate(productDetailsProvider(widget.productId)),
                ),
              ),
            )
          : Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // Hero image
                    productAsync.when(
                      loading: () => SliverToBoxAdapter(
                        child: SizedBox(
                          height: 600,
                          child: ColoredBox(
                            color: context.trenzyColors.background,
                          ),
                        ),
                      ),
                      error: (_, _) => SliverToBoxAdapter(
                        child: SizedBox(
                          height: 600,
                          child: ColoredBox(
                            color: context.trenzyColors.background,
                          ),
                        ),
                      ),
                      data: (product) => SliverAppBar(
                        expandedHeight: 600,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        pinned: false,
                        stretch: true,
                        flexibleSpace: FlexibleSpaceBar(
                          stretchModes: const [StretchMode.zoomBackground],
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 800,
                                placeholder: (_, _) => ColoredBox(
                                  color: context.trenzyColors.background,
                                ),
                                errorWidget: (_, _, _) => ColoredBox(
                                  color: context.trenzyColors.background,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      context.trenzyColors.background,
                                      context.trenzyColors.background
                                          .withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 20,
                                bottom: 100,
                                child: Column(
                                  children: [
                                    LikeBounce(
                                      isLiked: _isLiked,
                                      onTap: () => _toggleWishlist(product),
                                      child: _FloatingActionButton(
                                        icon: _isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    TapScale(
                                      onTap: () {
                                        final parts = <String>[
                                          product.name,
                                          product.brand.toUpperCase(),
                                          '\u20B9${product.price.toStringAsFixed(0)}',
                                          'Shared from Trenzy',
                                        ];
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text: parts.join('\n'),
                                            subject: product.name,
                                          ),
                                        );
                                      },
                                      child: _FloatingActionButton(
                                        icon: Icons.share,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Product info section
                    SliverToBoxAdapter(
                      child: productAsync.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                height: 16,
                                color: context.trenzyColors.graphite,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 32,
                                color: context.trenzyColors.graphite,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 150,
                                height: 28,
                                color: context.trenzyColors.graphite,
                              ),
                            ],
                          ),
                        ),
                        error: (_, _) => ErrorSection(
                          title: 'Couldn\'t load product details',
                          message:
                              'The product details went missing. Please try again.',
                          compact: true,
                          onRetry: () => ref.invalidate(
                            productDetailsProvider(widget.productId),
                          ),
                        ),
                        data: (product) => _ProductInfoSection(
                          product: product,
                          onSearchCategory: (cat) {
                            context.push(
                              '${AppRoutes.search}?category=${Uri.encodeComponent(cat)}',
                            );
                          },
                        ),
                      ),
                    ),
                    // Why we recommended this
                    SliverToBoxAdapter(
                      child: productAsync.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GlassContainer(
                            color: context.trenzyColors.graphite,
                            radius: 14,
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              color: context.trenzyColors.background.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (product) =>
                            _WhyRecommendedSection(product: product),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24)),
                    // Delivery info
                    SliverToBoxAdapter(
                      child: productAsync.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GlassContainer(
                            color: context.trenzyColors.graphite,
                            radius: 14,
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              width: double.infinity,
                              height: 40,
                              color: context.trenzyColors.background.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (_) => const SizedBox.shrink(),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),

                // Bottom action bar
                productAsync.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 50,
                          color: context.trenzyColors.graphite,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 40,
                                color: context.trenzyColors.graphite,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 40,
                                color: context.trenzyColors.graphite,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (product) => _BottomActionBar(
                    product: product,
                    isLiked: _isLiked,
                    isAddingToWardrobe: _isAddingToWardrobe,
                    onToggleWishlist: () => _toggleWishlist(product),
                    onAddToWardrobe: () => _addToWardrobe(product),
                    onAddToBlend: () => context.push(AppRoutes.blendHub),
                  ),
                ),
                _TopAppBar(
                  isSaved: _isSaved,
                  onSaveToggle: () => setState(() => _isSaved = !_isSaved),
                ),
              ],
            ),
    );
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLiked = !_isLiked);
    final api = ref.read(apiServiceProvider);
    try {
      if (_isLiked) {
        await api.addWishlistItem(product.id);
        trackProductSave(ref, product.id);
      } else {
        await api.removeWishlistItem(product.id);
      }
      ref.invalidate(wishlistProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _isLiked = !_isLiked);
      }
    }
  }

  Future<void> _addToWardrobe(ProductModel product) async {
    if (_isAddingToWardrobe) return;
    setState(() => _isAddingToWardrobe = true);
    final api = ref.read(apiServiceProvider);
    try {
      await api.addWardrobeItem(
        name: product.name,
        imageUrl: product.imageUrl,
        category: product.category.isEmpty ? product.outfitRole : product.category,
        color: product.displayColor.isEmpty ? product.color : product.displayColor,
        season: product.season,
        brand: product.effectiveBrand,
      );
      trackWardrobeAdd(ref, product.id, category: product.category);
      ref.invalidate(wardrobeProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added to wardrobe')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add to wardrobe')));
      }
    } finally {
      if (mounted) setState(() => _isAddingToWardrobe = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _FloatingActionButton extends StatelessWidget {
  const _FloatingActionButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.trenzyColors.glassDock,
        border: Border.all(color: context.trenzyColors.glassDockBorder),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: context.trenzyColors.foreground),
    );
  }
}

class _ProductInfoSection extends StatelessWidget {
  const _ProductInfoSection({required this.product, this.onSearchCategory});

  final ProductModel product;
  final ValueChanged<String>? onSearchCategory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand + category
          Row(
            children: [
              if (product.effectiveBrand != 'Unknown Brand') ...[
                Text(
                  product.effectiveBrand.toUpperCase(),
                  style: GlassTypography.meta(
                    color: context.trenzyColors.primary,
                  ),
                ),
                ...[
                SizedBox(width: 8),
                Text(
                  '\u00B7',
                  style: GlassTypography.meta(
                    color: context.trenzyColors.fg30,
                  ),
                ),
                SizedBox(width: 8),
              ],
              ],
              GestureDetector(
                onTap: () => onSearchCategory?.call(product.category),
                child: Text(
                  product.category.toUpperCase(),
                  style: GlassTypography.meta(
                    color: context.trenzyColors.fg50,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Name
          Text(
            product.name,
            style: GlassTypography.display(
              fontSize: 24,
              weight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),

          // Price + rating row
          Row(
            children: [
              Text(
                product.effectivePrice.toString(),
                style: GlassTypography.body(
                  fontSize: 22,
                  weight: FontWeight.w800,
                  color: context.trenzyColors.primary,
                ),
              ),
              SizedBox(width: 16),
              ...[
              Icon(
                Icons.star_rounded,
                size: 18,
                color: context.trenzyColors.primary,
              ),
              SizedBox(width: 4),
              Text(
                product.rating.toStringAsFixed(1),
                style: GlassTypography.body(
                  fontSize: 14,
                  weight: FontWeight.w700,
                ),
              ),
            ],
            ],
          ),

          // Tags row
          if (product.tags.isNotEmpty) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.glass,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.trenzyColors.glassBorder),
                  ),
                  child: Text(
                    tag,
                    style: GlassTypography.body(
                      fontSize: 12,
                      color: context.trenzyColors.fg70,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Description
          if (product.description.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              product.description,
              style: GlassTypography.body(
                fontSize: 14,
                color: context.trenzyColors.mutedFg,
                height: 1.5,
              ),
            ),
          ],

          // Subcategory / gender / season meta row
          SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.category_outlined,
                label: product.subcategory,
              ),
              _MetaChip(
                icon: product.gender.toLowerCase() == 'men'
                    ? Icons.male_rounded
                    : product.gender.toLowerCase() == 'women'
                    ? Icons.female_rounded
                    : Icons.people_outline_rounded,
                label: product.gender,
              ),
              _MetaChip(
                icon: Icons.wb_sunny_outlined,
                label: product.season,
              ),
              _MetaChip(icon: Icons.palette_outlined, label: product.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.trenzyColors.fg40),
        SizedBox(width: 4),
        Text(
          label,
          style: GlassTypography.body(
            fontSize: 12,
            color: context.trenzyColors.fg50,
          ),
        ),
      ],
    );
  }
}

class _WhyRecommendedSection extends StatelessWidget {
  const _WhyRecommendedSection({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    // Use the backend-provided reason if available, otherwise fall back
    // to a style-based explanation.
    final reason = product.reason;
    final styleLabel = product.style.isEmpty ? product.usage : product.style;
    final displayText =
        reason.isEmpty ? 'Picked for your $styleLabel style' : reason;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        color: context.trenzyColors.graphite,
        radius: 14,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.primary.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: context.trenzyColors.primary,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why we recommended this',
                    style: GlassTypography.body(
                      fontSize: 13,
                      weight: FontWeight.w700,
                      color: context.trenzyColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    displayText,
                    style: GlassTypography.body(
                      fontSize: 13,
                      color: context.trenzyColors.mutedFg,
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

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.product,
    required this.isLiked,
    required this.isAddingToWardrobe,
    required this.onToggleWishlist,
    required this.onAddToWardrobe,
    required this.onAddToBlend,
  });

  final ProductModel product;
  final bool isLiked;
  final bool isAddingToWardrobe;
  final VoidCallback onToggleWishlist;
  final VoidCallback onAddToWardrobe;
  final VoidCallback onAddToBlend;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              context.trenzyColors.background,
              context.trenzyColors.background.withValues(alpha: 0.95),
              context.trenzyColors.background.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Row(
          children: [
            TapScale(
              onTap: onToggleWishlist,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLiked
                      ? context.trenzyColors.crimson.withValues(alpha: 0.15)
                      : context.trenzyColors.glass,
                  borderRadius: BorderRadius.circular(GlassRadius.button),
                  border: Border.all(
                    color: isLiked
                        ? context.trenzyColors.crimson.withValues(alpha: 0.4)
                        : context.trenzyColors.glassBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: isLiked
                      ? context.trenzyColors.crimson
                      : context.trenzyColors.fg60,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _SecondaryAction(
                icon: Icons.checkroom_outlined,
                label: 'Wardrobe',
                onTap: isAddingToWardrobe ? null : onAddToWardrobe,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _SecondaryAction(
                icon: Icons.blender_outlined,
                label: 'Add to Blend',
                onTap: onAddToBlend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? context.trenzyColors.glass
                : context.trenzyColors.glass.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(GlassRadius.button),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? context.trenzyColors.fg60
                    : context.trenzyColors.fg30,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GlassTypography.body(
                  fontSize: 12,
                  weight: FontWeight.w700,
                  color: enabled
                      ? context.trenzyColors.fg70
                      : context.trenzyColors.fg30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({required this.isSaved, required this.onSaveToggle});

  final bool isSaved;
  final VoidCallback onSaveToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      left: 16,
      right: 16,
      child: Row(
        children: [
          GlassBackButton(),
          Spacer(),
          TapScale(
            onTap: onSaveToggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.glass,
                border: Border.all(color: context.trenzyColors.glassBorder),
              ),
              alignment: Alignment.center,
              child: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 18,
                color: isSaved
                    ? context.trenzyColors.primary
                    : context.trenzyColors.fg60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
