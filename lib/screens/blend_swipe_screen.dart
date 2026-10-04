import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/models/blend_model.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/widgets/section_states.dart';
import 'package:trenzy/services/blend_socket_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/analytics/events.dart';

class BlendSwipeScreen extends ConsumerWidget {
  const BlendSwipeScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: EmptySection(
            title: 'No group selected',
            subtitle: 'Select an active blend group to start swiping.',
            actionLabel: 'Go to Blend Hub',
            onAction: () => context.go(AppRoutes.blendHub),
          ),
        ),
      );
    }

    final groupAsync = ref.watch(blendGroupProvider(groupId));

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(child: LoadingSkeletonShimmer(height: 200, radius: 20)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: ErrorSection(
            title: 'Could not load products',
            message: friendlyError(err),
            onRetry: () => ref.invalidate(blendGroupProvider(groupId)),
          ),
        ),
      ),
      data: (group) => _BlendSwipeContent(group: group, groupId: groupId),
    );
  }
}

class _BlendSwipeContent extends ConsumerStatefulWidget {
  const _BlendSwipeContent({required this.group, required this.groupId});

  final BlendGroup group;
  final String groupId;

  @override
  ConsumerState<_BlendSwipeContent> createState() => _BlendSwipeContentState();
}

class _BlendSwipeContentState extends ConsumerState<_BlendSwipeContent>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  double _dragX = 0;
  double _dragY = 0;
  bool _isAnimating = false;

  late final AnimationController _swipeAnimator;
  late final Animation<double> _exitAnimation;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnimation;

  final _swipeHistory = <String, String>{};
  StreamSubscription<BlendLiveState>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _swipeSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _connectionSub;
  BlendLiveState? _liveState;

  List<ProductModel> get _products => widget.group.options;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _swipeAnimator = AnimationController(duration: Duration(milliseconds: 400), vsync: this);
    _exitAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _swipeAnimator,
      curve: Curves.easeIn,
    ));

    _enterController = AnimationController(duration: Duration(milliseconds: 350), vsync: this);
    _enterAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutBack,
    ));
    _enterController.value = 1;

    _listenToLiveState();
  }

  void _listenToLiveState() {
    _stateSub = BlendSocketService.instance.stateStream.listen((state) {
      if (mounted && state.groupId == widget.groupId) {
        setState(() => _liveState = state);
      }
    });

    // P1: Listen for lightweight swipe_applied events from other users
    // These provide immediate UI feedback (toast) without full state recompute
    _swipeSub = BlendSocketService.instance.swipeAppliedStream.listen((swipeEvent) {
      if (!mounted) return;

      // Only show toast for other users' swipes, not our own
      final userId = swipeEvent['userId'];
      final userName = swipeEvent['userName'] ?? 'Member';
      final swipeType = swipeEvent['swipeType'] ?? 'liked';

      if (userId != null) {
        final verb = swipeType == 'love' ? 'loved' : (swipeType == 'like' ? 'liked' : 'passed on');
        GlassToast.info(context, '$userName $verb this');
      }
    });

    // P0 ERROR: Listen for socket errors (expired invite, revoked access, etc.)
    // to ensure we don't crash and show user-friendly messaging
    // FIXED: Store subscription to cancel in dispose() and prevent memory leaks
    _errorSub?.cancel();
    _errorSub = BlendSocketService.instance.errorStream.listen((error) {
      if (!mounted) return;
      _handleSocketError(error);
    });

    // P1 RESYNC: Listen to connection state to trigger full state refresh on reconnect
    _connectionSub?.cancel();
    _connectionSub = BlendSocketService.instance.connectionStateStream.listen((isConnected) {
      if (isConnected && mounted) {
        // On successful reconnect, fetch full blend state to sync any missed events
        BlendSocketService.instance.getBlendState(widget.groupId);
      }
    });
  }

  void _handleSocketError(String error) {
    if (!mounted) return;

    // Distinguish between critical auth failures and transient connection errors
    bool isCritical = error.contains('token') ||
        error.contains('expired') ||
        error.contains('revoked') ||
        error.contains('Not authenticated') ||
        error.contains('forbidden');

    if (isCritical) {
      // Session expired or auth failed - nav to re-auth
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your access expired. Please sign in again.'),
          backgroundColor: context.trenzyColors.crimson,
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () {
              context.go(AppRoutes.login);
            },
          ),
        ),
      );
    } else {
      // Transient connection error - user can continue
      GlassToast.error(context, 'Connection issue. Please try again.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _swipeSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    _swipeAnimator.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // P1 RESYNC: When app returns to foreground, fetch fresh blend state if connected
    if (state == AppLifecycleState.resumed &&
        BlendSocketService.instance.isConnected &&
        mounted) {
      BlendSocketService.instance.getBlendState(widget.groupId);
    }
  }

  void _recordSwipe(String productId, String type) {
    _swipeHistory[productId] = type;
    _sendSwipeToServer(productId, type);
    trackBlendSwipe(ref, widget.groupId, productId, type);
  }

  void _sendSwipeToServer(String productId, String type) {
    final api = ref.read(apiServiceProvider);
    api.recordBlendSwipe(
      groupId: widget.groupId,
      productId: productId,
      swipeType: type,
    ).catchError((e) {
      debugPrint('[BlendSwipe] Failed to record swipe: $e');
    });
  }

  bool get _allSwiped => _currentIndex >= _products.length;

  void _swipeAway(String type) {
    if (_isAnimating) return;
    _isAnimating = true;

    final product = _products[_currentIndex];
    _recordSwipe(product.id, type);
    HapticFeedback.mediumImpact();

    _swipeAnimator.reset();
    _swipeAnimator.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
      _enterController.reset();
      _enterController.forward();
    });
  }

  void _undoLastSwipe() {
    if (_currentIndex <= 0 || _isAnimating) return;
    HapticFeedback.lightImpact();
    final undoneProduct = _products[_currentIndex - 1];
    // Undo is now server-backed: remove the swipe vote so results and
    // other members' views reflect the correction, not just this device.
    final api = ref.read(apiServiceProvider);
    api.undoBlendSwipe(
      groupId: widget.groupId,
      productId: undoneProduct.id,
    ).catchError((e) {
      debugPrint('[BlendSwipe] Failed to undo swipe: $e');
    });
    setState(() {
      _currentIndex--;
      if (_currentIndex < _products.length) {
        _swipeHistory.remove(_products[_currentIndex].id);
      }
      _dragX = 0;
      _dragY = 0;
    });
  }

  void _snapBack() {
    setState(() {
      _dragX = 0;
      _dragY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        appBar: AppBar(
          backgroundColor: context.trenzyColors.background,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
            onPressed: () => context.go(AppRoutes.blendHub),
          ),
          title: Text('Swipe', style: TextStyle(color: context.trenzyColors.foreground)),
        ),
        body: Center(
          child: EmptySection(
            title: 'No products to swipe on',
            subtitle: 'This Blend group doesn\u2019t have any products added yet.',
            actionLabel: 'Go to Blend Hub',
            onAction: () => context.go(AppRoutes.blendHub),
          ),
        ),
      );
    }

    if (_allSwiped) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        appBar: AppBar(
          backgroundColor: context.trenzyColors.background,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
            onPressed: () => context.go(AppRoutes.blendHub),
          ),
          title: Text('Session Complete', style: TextStyle(color: context.trenzyColors.foreground)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.trenzyColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.check_circle_outline, color: context.trenzyColors.primary, size: 48),
                ),
                SizedBox(height: 24),
                DisplayText("You've seen everything!", fontSize: 22, weight: FontWeight.w700),
                SizedBox(height: 8),
                Text(
                  '${_swipeHistory.length} products swiped in this session',
                  style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 14),
                ),
                SizedBox(height: 32),
                GlowButton(
                  label: 'View Results',
                  icon: Icons.bar_chart_rounded,
                  width: 220,
                  height: 48,
                  onTap: () => context.go('${AppRoutes.blendResults}?groupId=${widget.groupId}'),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.discover),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.trenzyColors.foreground,
                    side: BorderSide(color: context.trenzyColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Explore More Styles'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final product = _products[_currentIndex];

    final exitOffset = _isAnimating
        ? Offset(
            _dragX.sign * 600 * _exitAnimation.value,
            _dragX.sign * 200 * _exitAnimation.value,
          )
        : Offset.zero;

    final exitRotation = _isAnimating
        ? _dragX / 500 + _dragX.sign * 0.5 * _exitAnimation.value
        : _dragX / 500;

    final exitOpacity = _isAnimating ? 1 - _exitAnimation.value : 1.0;

    final enterScale = _enterAnimation.value;
    final enterOpacity = _enterAnimation.value;

    final mySwipes = _swipeHistory.length;
    final groupSwipes = _liveState?.totalSwipes ?? widget.group.members.fold<int>(0, (sum, m) => sum + m.swipeCount);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: context.trenzyColors.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => context.go(AppRoutes.blendHub),
        ),
        title: Text(
          'You $mySwipes \u00B7 Group $groupSwipes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.trenzyColors.primary,
          ),
        ),
        actions: [
          if (widget.group.members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: widget.group.members.take(3).map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: context.trenzyColors.graphite,
                      child: Text(
                        m.userName.isNotEmpty ? m.userName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 12, color: context.trenzyColors.primary),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onPanUpdate: _isAnimating
            ? null
            : (details) {
                setState(() {
                  _dragX += details.delta.dx;
                  _dragY += details.delta.dy;
                });
              },
        onPanEnd: _isAnimating
            ? null
            : (details) {
                if (_dragX.abs() > 100) {
                  _swipeAway(_dragX > 0 ? 'like' : 'dislike');
                } else {
                  _snapBack();
                }
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isAnimating)
              Opacity(
                opacity: exitOpacity.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(_dragX + exitOffset.dx, _dragY + exitOffset.dy),
                  child: Transform.rotate(
                    angle: exitRotation,
                    child: _ProductCard(product: product),
                  ),
                ),
              ),
            Opacity(
              opacity: _isAnimating ? enterOpacity : 1.0,
              child: Transform.scale(
                scale: _isAnimating ? enterScale : 1.0,
                child: _isAnimating && _currentIndex + 1 < _products.length
                    ? Opacity(
                        opacity: 0.3,
                        child: _ProductCard(product: _products[_currentIndex + 1]),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (!_isAnimating)
              Transform.translate(
                offset: Offset(_dragX, _dragY),
                child: Transform.rotate(
                  angle: _dragX / 500,
                  child: _ProductCard(product: product),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SwipeButton(
                icon: Icons.close,
                color: context.trenzyColors.crimson,
                onTap: _isAnimating ? null : () => _swipeAway('dislike'),
              ),
              _SwipeButton(
                icon: Icons.undo_rounded,
                color: context.trenzyColors.mutedFg,
                size: 40,
                onTap: _currentIndex > 0 && !_isAnimating ? _undoLastSwipe : null,
              ),
              _SwipeButton(
                icon: Icons.favorite,
                color: context.trenzyColors.primary,
                onTap: _isAnimating ? null : () => _swipeAway('love'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 420,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.trenzyColors.foreground.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, _) => Center(child: Icon(Icons.image_outlined, color: context.trenzyColors.mutedFg, size: 24)),
                  errorWidget: (_, _, _) => Center(child: Icon(Icons.image, color: context.trenzyColors.mutedFg)),
                  )
                : Center(child: Icon(Icons.image, color: context.trenzyColors.mutedFg, size: 48)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  product.brand ?? '',
                  style: TextStyle(fontSize: 14, color: context.trenzyColors.mutedFg),
                ),
                SizedBox(height: 8),
                Text(
                  product.effectivePrice,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.trenzyColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _SwipeButton({
    required this.icon,
    required this.color,
    this.size = 64,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}
