import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/services/api_service.dart';
import 'package:trenzy/utils/ai_explanations.dart';
import 'package:trenzy/analytics/events.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/router/app_router.dart';

class SwipeDiscoveryScreen extends ConsumerStatefulWidget {
  const SwipeDiscoveryScreen({super.key});

  @override
  ConsumerState<SwipeDiscoveryScreen> createState() => _SwipeDiscoveryScreenState();
}

class _SwipeDiscoveryScreenState extends ConsumerState<SwipeDiscoveryScreen>
    with TickerProviderStateMixin {
  final _products = <ProductModel>[];
  int _currentIndex = 0;

  late final AnimationController _swipeAnimator;
  late final AnimationController _stackAnimator;

  double _dragX = 0;
  double _dragY = 0;
  double _rotation = 0;

  final _likedProducts = <String>[];
  final _savedProducts = <String>[];
  int _totalSwipes = 0;
  bool _showLearningFeedback = false;
  String _learningInsights = '';
  Timer? _feedbackTimer;
  VoidCallback? _currentAnimListener;
  AnimationStatusListener? _currentStatusListener;

  @override
  void initState() {
    super.initState();
    _swipeAnimator = AnimationController(
      duration: GlassAnimations.feature,
      vsync: this,
    );
    _stackAnimator = AnimationController(
      duration: GlassAnimations.everyday,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _removeAnimationListeners();
    _swipeAnimator.dispose();
    _stackAnimator.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _removeAnimationListeners() {
    if (_currentAnimListener != null) {
      _swipeAnimator.removeListener(_currentAnimListener!);
      _currentAnimListener = null;
    }
    if (_currentStatusListener != null) {
      _swipeAnimator.removeStatusListener(_currentStatusListener!);
      _currentStatusListener = null;
    }
  }

  void _swipeLeft() => _animateSwipe(-1);
  void _swipeRight() => _animateSwipe(1);

  void _recordSwipeToServer(String productId, String swipeType) {
    final api = ref.read(apiServiceProvider);
    api.recordDiscoverySwipe(productId: productId, swipeType: swipeType).catchError((e) {
      debugPrint('[SwipeDiscovery] Failed to record swipe: $e');
    });
  }

  void _showFeedbackAfterSwipe() {
    _totalSwipes++;
    if (_totalSwipes > 0 && _totalSwipes % 5 == 0 && _likedProducts.isNotEmpty) {
      final liked = _likedProducts.map((id) {
        try {
          return _products.firstWhere((p) => p.id == id);
        } catch (_) {
          return null;
        }
      }).whereType<ProductModel>().toList();
      final disliked = <ProductModel>[];
      _learningInsights = generateSessionSummary(liked, disliked);
      setState(() => _showLearningFeedback = true);
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showLearningFeedback = false);
      });
    }
  }

  void _animateSwipe(int direction) {
    if (_currentIndex >= _products.length) return;

    final product = _products[_currentIndex];
    if (direction < 0) {
      _recordSwipeToServer(product.id, 'dislike');
    } else if (direction > 0) {
      if (!_likedProducts.contains(product.id)) {
        _likedProducts.add(product.id);
      }
      _recordSwipeToServer(product.id, 'like');
    }

    _showFeedbackAfterSwipe();

    HapticFeedback.mediumImpact();
    _removeAnimationListeners();
    _swipeAnimator.reset();

    final endX = direction * MediaQuery.of(context).size.width * 1.5;

    _currentAnimListener = () {
      final progress = _swipeAnimator.value;
      setState(() {
        _dragX = endX * Curves.easeInOutCubic.transform(progress);
        _dragY = 50 * sin(progress * pi);
        _rotation = direction * 0.25 * progress;
      });
    };

    _currentStatusListener = (status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex++;
          _dragX = 0;
          _dragY = 0;
          _rotation = 0;
        });
        _removeAnimationListeners();
      }
    };

    _swipeAnimator.addListener(_currentAnimListener!);
    _swipeAnimator.addStatusListener(_currentStatusListener!);
    _swipeAnimator.forward();
  }

  void _saveProduct() {
    if (_currentIndex >= _products.length) return;
    final product = _products[_currentIndex];
    if (!_savedProducts.contains(product.id)) {
      HapticFeedback.lightImpact();
      setState(() {
        _savedProducts.add(product.id);
      });
      trackProductSave(ref, product.id);
      _recordSwipeToServer(product.id, 'save');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved!'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: context.trenzyColors.emerald,
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _likeProduct() {
    if (_currentIndex >= _products.length) return;
    final product = _products[_currentIndex];
    if (!_likedProducts.contains(product.id)) {
      _likedProducts.add(product.id);
    }
    trackSwipe(ref, product.id, 'like');
    _swipeRight();
  }

  Widget _buildCard(int index) {
    if (index >= _products.length) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    final product = _products[index];
    final isTop = index == _currentIndex;
    final stackIndex = index - _currentIndex;

    if (stackIndex < 0 || stackIndex > 3) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    final scale = max(1.0 - stackIndex * 0.04, 0.88);
    final translateY = stackIndex * 8.0;
    final opacity = (1.0 - stackIndex * 0.3).clamp(0.0, 1.0);

    Widget card = Opacity(
      opacity: isTop ? 1.0 : opacity,
      child: Transform.translate(
        offset: isTop
            ? Offset(_dragX, _dragY)
            : Offset(0, translateY),
        child: Transform.scale(
          scale: isTop ? 1.0 : scale,
          child: isTop
              ? _buildDraggableCard(product)
              : _buildStaticCard(product, index),
        ),
      ),
    );

    if (!isTop) {
      card = IgnorePointer(child: card);
    }

    return Positioned.fill(child: card);
  }

  Widget _buildStaticCard(ProductModel product, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassRadius.card),
        border: Border.all(color: context.trenzyColors.glassBorder),
        boxShadow: [GlassShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: ApiService.resolveImageUrl(product.imageUrl) ?? 'https://placehold.co/400x600/1a1a2e/666.png?text=No+Image',
            fit: BoxFit.cover,
            placeholder: (_, _) => _cardPlaceholder(),
            errorWidget: (_, _, _) => _cardPlaceholder(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableCard(ProductModel product) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _dragX += details.delta.dx;
          _dragY += details.delta.dy;
          _rotation = (_dragX / 300).clamp(-0.3, 0.3);
        });
      },
      onPanEnd: (details) {
        final threshold = MediaQuery.of(context).size.width * 0.25;
        if (_dragX.abs() > threshold) {
          _animateSwipe(_dragX.sign.toInt());
        } else {
          _swipeAnimator.reset();
          setState(() {
            _dragX = 0;
            _dragY = 0;
            _rotation = 0;
          });
        }
      },
      child: Transform.rotate(
        angle: _rotation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GlassRadius.card),
            border: Border.all(color: context.trenzyColors.glassBorder, width: 1.5),
            boxShadow: [
              GlassShadows.card,
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: -4,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: ApiService.resolveImageUrl(product.imageUrl) ?? 'https://placehold.co/400x600/1a1a2e/666.png?text=No+Image',
                fit: BoxFit.cover,
                placeholder: (_, _) => _cardPlaceholder(),
                errorWidget: (_, _, _) => _cardPlaceholder(),
              ),
              // ── LIKE overlay ─────────────────────────────────────────
              if (_dragX > 30)
                Positioned(
                  top: 32,
                  left: 24,
                  child: Transform.rotate(
                    angle: -0.15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.emerald,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.trenzyColors.emerald.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        'LIKE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              // ── NOPE overlay ─────────────────────────────────────────
              if (_dragX < -30)
                Positioned(
                  top: 32,
                  right: 24,
                  child: Transform.rotate(
                    angle: 0.15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.crimson,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.trenzyColors.crimson.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        'NOPE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              // ── Bottom gradient + product info ───────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 48,
                    bottom: 20,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.black54,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            product.brand ?? '',
                            style: TextStyle(
                              color: context.trenzyColors.fg70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Spacer(),
                          // Price badge with gradient
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: GlassGradients.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: context.trenzyColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              '₹${(product.price ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: context.trenzyColors.primaryFg,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Tag chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _tagChip(product.category ?? ''),
                          if (product.color != null)
                            _tagChip(product.color!),
                          if (product.tags != null && product.tags!.isNotEmpty)
                            _tagChip(product.tags!.first),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // ── Bookmark indicator ───────────────────────────────────
              if (_savedProducts.contains(product.id))
                Positioned(
                  top: 16,
                  right: 16,
                  child: Icon(
                    Icons.bookmark_rounded,
                    color: context.trenzyColors.primary,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.trenzyColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.trenzyColors.fg80,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cardPlaceholder() {
    return Container(
      color: context.trenzyColors.graphite,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: context.trenzyColors.fg20,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: context.trenzyColors.fg20,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(discoverSwipeProductsProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Glass header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassBackButton(
                    onTap: () => context.pop(),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SWIPE DISCOVERY',
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
                          'Find your next favorite',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.trenzyColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Counter badge
                  if (_products.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.glass,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.trenzyColors.glassBorder),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${_products.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.trenzyColors.mutedFg,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Card stack ──────────────────────────────────────────────
            Expanded(
              child: productsAsync.when(
                loading: () => Center(
                  child: LoadingSkeletonShimmer(
                    height: 400,
                    width: 300,
                    radius: GlassRadius.card,
                  ),
                ),
                error: (err, _) => _ErrorView(
                  onRetry: () => ref.invalidate(discoverSwipeProductsProvider),
                ),
                data: (products) {
                  if (_products.isEmpty && products.isNotEmpty) {
                    _products.addAll(products);
                  }
                  final allSwiped = _products.isNotEmpty && _currentIndex >= _products.length;
                  if (_products.isEmpty || allSwiped) {
                    return _PersonalizedCompleteView(
                      likedCount: _likedProducts.length,
                      savedCount: _savedProducts.length,
                      totalSwiped: _products.length,
                      onRefresh: () {
                        ref.invalidate(discoverSwipeProductsProvider);
                        setState(() {
                          _products.clear();
                          _currentIndex = 0;
                          _likedProducts.clear();
                          _savedProducts.clear();
                        });
                      },
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            ...List.generate(
                              min(_products.length - _currentIndex, 4),
                              (i) => _buildCard(_currentIndex + i),
                            ).reversed,
                            if (_showLearningFeedback)
                              Positioned(
                                top: 20,
                                left: 20,
                                right: 20,
                                child: Material(
                                  color: Colors.transparent,
                                  child: AnimatedOpacity(
                                    opacity: 1,
                                    duration: Duration(milliseconds: 300),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: context.trenzyColors.surfaceContainer.withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.3)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome_rounded,
                                              size: 20, color: context.trenzyColors.primary),
                                          SizedBox(height: 8),
                                          Text(
                                            'Learning your preferences...',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: context.trenzyColors.foreground,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            _learningInsights,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.trenzyColors.mutedFg,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Recommendations will adapt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.trenzyColors.mutedFg.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // ── Action buttons ──────────────────────────────────────────
            if (_products.isNotEmpty && _currentIndex < _products.length)
              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  top: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionBtn(
                      icon: Icons.close_rounded,
                      color: context.trenzyColors.crimson,
                      size: 56,
                      onTap: _swipeLeft,
                      label: 'Nope',
                    ),
                    _ActionBtn(
                      icon: Icons.bookmark_outline_rounded,
                      color: context.trenzyColors.primary,
                      size: 44,
                      onTap: _saveProduct,
                      label: 'Save',
                      small: true,
                    ),
                    _ActionBtn(
                      icon: Icons.favorite_rounded,
                      color: context.trenzyColors.emerald,
                      size: 56,
                      onTap: _likeProduct,
                      label: 'Like',
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

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String label;
  final bool small;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    required this.label,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: GlassTypography.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.crimson.withValues(alpha: 0.1),
                border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.2)),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: context.trenzyColors.crimson,
                size: 32,
              ),
            ),
            SizedBox(height: 20),
            DisplayText('Something went wrong', fontSize: 18, weight: FontWeight.w700),
            SizedBox(height: 8),
            Text(
              'Could not load products to discover.',
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            GlowButton(
              label: 'Retry',
              width: 140,
              height: 44,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalizedCompleteView extends StatelessWidget {
  final int likedCount;
  final int savedCount;
  final int totalSwiped;
  final VoidCallback onRefresh;

  const _PersonalizedCompleteView({
    required this.likedCount,
    required this.savedCount,
    required this.totalSwiped,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GlassGradients.primary,
                boxShadow: [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: context.trenzyColors.primaryFg,
                size: 40,
              ),
            ),
            SizedBox(height: 24),
            DisplayText('Your style is taking shape!', fontSize: 22, weight: FontWeight.w700),
            SizedBox(height: 12),
            Text(
              'Based on your swipes, we\'re tailoring recommendations just for you.',
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatBadge(
                  icon: Icons.favorite_rounded,
                  count: likedCount,
                  label: 'Liked',
                  color: context.trenzyColors.emerald,
                ),
                SizedBox(width: 16),
                _StatBadge(
                  icon: Icons.bookmark_rounded,
                  count: savedCount,
                  label: 'Saved',
                  color: context.trenzyColors.primary,
                ),
                SizedBox(width: 16),
                _StatBadge(
                  icon: Icons.swipe_rounded,
                  count: totalSwiped,
                  label: 'Swiped',
                  color: context.trenzyColors.mutedFg,
                ),
              ],
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: 'Explore Personalized Feed',
                icon: Icons.explore_rounded,
                height: 48,
                onTap: () {
                  if (context.mounted) {
                    context.go(AppRoutes.discover);
                  }
                },
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onRefresh,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: context.trenzyColors.glassBorder),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: context.trenzyColors.mutedFg),
                    SizedBox(width: 8),
                    Text(
                      'Swipe More Products',
                      style: TextStyle(
                        color: context.trenzyColors.mutedFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}