import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/models/blend_model.dart';
import 'package:trenzy/models/product_model.dart';
import 'package:trenzy/providers/auth_provider.dart' as auth_p;
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/services/blend_socket_service.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart';

class LiveBlendSessionScreen extends ConsumerStatefulWidget {
  const LiveBlendSessionScreen({super.key});

  @override
  ConsumerState<LiveBlendSessionScreen> createState() =>
      _LiveBlendSessionScreenState();
}

class _LiveBlendSessionScreenState extends ConsumerState<LiveBlendSessionScreen>
    with WidgetsBindingObserver {
  BlendLiveState? _liveState;
  String? _groupId;
  StreamSubscription<BlendLiveState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<Map<String, dynamic>>? _swipeSub;
  StreamSubscription<bool>? _connectionSub;
  Map<String, dynamic>? _lastSwipeEvent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final params = GoRouterState.of(context).uri.queryParameters;
    final gid = params['groupId'];
    if (gid != null && gid != _groupId) {
      _groupId = gid;
      _joinBlend();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _errorSub?.cancel();
    _swipeSub?.cancel();
    _connectionSub?.cancel();
    if (_groupId != null) {
      BlendSocketService.instance.leaveBlend(groupId: _groupId!);
    }
    super.dispose();
  }

  void _joinBlend() {
    if (_groupId == null) return;
    final user = ref.read(auth_p.authProvider).valueOrNull;
    if (user == null) return;

    BlendSocketService.instance.joinBlend(
      groupId: _groupId!,
      userId: user.id,
      userName: user.name,
    );

    _stateSub?.cancel();
    _stateSub = BlendSocketService.instance.stateStream.listen((state) {
      if (mounted && state.groupId == _groupId) {
        setState(() => _liveState = state);
      }
    });

    _errorSub?.cancel();
    _errorSub = BlendSocketService.instance.errorStream.listen((error) {
      if (mounted) {
        _handleSocketError(error);
      }
    });

    // P1: Listen to swipe_applied events for real-time activity feed updates
    _swipeSub?.cancel();
    _swipeSub = BlendSocketService.instance.swipeAppliedStream.listen((swipeEvent) {
      if (mounted) {
        setState(() => _lastSwipeEvent = swipeEvent);
      }
    });

    // P1 RESYNC: Listen to connection state to trigger full state refresh on reconnect
    _connectionSub?.cancel();
    _connectionSub = BlendSocketService.instance.connectionStateStream.listen((isConnected) {
      if (isConnected && mounted) {
        // On successful reconnect, fetch full blend state to sync any missed events
        BlendSocketService.instance.getBlendState(_groupId!);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // P1 RESYNC: When app returns to foreground, fetch fresh blend state if connected
    if (state == AppLifecycleState.resumed &&
        BlendSocketService.instance.isConnected &&
        mounted &&
        _groupId != null) {
      BlendSocketService.instance.getBlendState(_groupId!);
    }
  }

  double get _compatibilityPercent {
    if (_liveState == null || _liveState!.memberCount <= 1) return 0;
    final swipesByMember = _liveState!.swipesByMember;
    if (swipesByMember.isEmpty) return 0;
    final membersWithSwipes = swipesByMember.entries.where((e) => e.value > 0).length;
    final memberRatio = membersWithSwipes / _liveState!.memberCount;
    final agreementRatio = _liveState!.totalSwipes > 0 ? (_liveState!.agreementScore ?? 0.5) : 0.0;
    return (memberRatio * 0.5 + agreementRatio * 0.5).clamp(0.0, 1.0);
  }

  String get _compatibilityLabel {
    final pct = _compatibilityPercent;
    if (pct >= 0.9) return 'Style Twins';
    if (pct >= 0.7) return 'Great Match';
    if (pct >= 0.5) return 'Good Taste';
    return 'Getting Started';
  }

  @override
  Widget build(BuildContext context) {
    final groupId = _groupId;
    final members = _liveState?.members ?? [];

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: Stack(
        children: [
          if (groupId == null)
            Center(child: CircularProgressIndicator(color: context.trenzyColors.primary))
          else
            _buildMainContent(groupId, members),
          _BottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildMainContent(String groupId, List<BlendMember> members) {
    final blendGroupAsync = ref.watch(blendGroupProvider(groupId));

    // P0 EDGE CASE: Last member left — show friendly message
    if (members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_remove, size: 64, color: context.trenzyColors.mutedFg.withValues(alpha: 0.5)),
              SizedBox(height: 24),
              Text(
                'Blend Ended',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground),
              ),
              SizedBox(height: 12),
              Text(
                'All members have left this session.',
                style: TextStyle(color: context.trenzyColors.mutedFg),
              ),
              SizedBox(height: 32),
              GlowButton(
                label: 'Go to Blend Hub',
                width: 220,
                height: 48,
                onTap: () => context.go(AppRoutes.blendHub),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      bottom: 90,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              SizedBox(height: 70),
              _buildLiveInteractionOverlay(members),
              SizedBox(height: 24),
              _buildCompatibilityMeter(),
              SizedBox(height: 24),
              blendGroupAsync.when(
                data: (group) => group.options.isNotEmpty
                    ? _buildProductCard(group.options.first, group)
                    : Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_bag_outlined, 
                              color: context.trenzyColors.mutedFg.withValues(alpha: 0.5), 
                              size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Waiting for products...',
                              style: TextStyle(color: context.trenzyColors.mutedFg),
                            ),
                          ],
                        ),
                      ),
                loading: () => Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: context.trenzyColors.primary),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, 
                        color: context.trenzyColors.crimson.withValues(alpha: 0.5), 
                        size: 48),
                      SizedBox(height: 16),
                      Text('Error loading products', 
                        style: TextStyle(color: context.trenzyColors.mutedFg)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),
              _buildFloatingControls(groupId),
              SizedBox(height: 24),
              _buildLiveActivityFeed(members),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveInteractionOverlay(List<BlendMember> members) {
    final activeMember = members.isNotEmpty ? members.first : null;
    final onlineMembers = _liveState?.onlineUserIds ?? [];
    final isActiveMemberOnline = activeMember != null && onlineMembers.contains(activeMember.userId);

    return GlassBlurredContainer(
      radius: 99,
      blurSigma: 24,
      color: context.trenzyColors.graphite.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              child: Stack(
                children: [
                  _buildAvatar(null, label: activeMember?.userName ?? 'U', isOnline: isActiveMemberOnline),
                  if (members.length > 1)
                    Positioned(
                      left: 20,
                      child: _buildAvatar(
                        null,
                        label: members[1].userName,
                        isOnline: onlineMembers.contains(members[1].userId),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE SESSION',
                  style: TextStyle(
                    color: context.trenzyColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  isActiveMemberOnline
                      ? '${activeMember.userName} is swiping...'
                      : '${onlineMembers.length}/${members.length} connected',
                  style: TextStyle(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, {bool isOnline = false, String? label}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.trenzyColors.background, width: 2),
      ),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.trenzyColors.graphite,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? Text(
                    label != null && label.isNotEmpty ? label[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: context.trenzyColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          // P1: Online indicator — green dot for connected users
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: context.trenzyColors.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.trenzyColors.background, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: context.trenzyColors.emerald.withValues(alpha: 0.5),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityMeter() {
    final pct = _compatibilityPercent;

    return Column(
      children: [
        Container(
          width: 280,
          height: 8,
          decoration: BoxDecoration(
            color: context.trenzyColors.graphite.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 600),
              width: 280 * pct,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: [Color(0xFFD4AF37), context.trenzyColors.primary, Color(0xFFFFE088)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${(pct * 100).round()}% Compatibility',
          style: TextStyle(
            color: context.trenzyColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 2),
        Text(
          _compatibilityLabel,
          style: TextStyle(
            color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product, BlendGroup group) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 60,
              offset: Offset(0, 30),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: product.imageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: context.trenzyColors.graphite,
                  child: Icon(Icons.checkroom, color: context.trenzyColors.mutedFg, size: 60),
                ),
                errorWidget: (_, _, _) => Container(
                  color: context.trenzyColors.graphite,
                  child: Icon(Icons.checkroom, color: context.trenzyColors.mutedFg, size: 60),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      context.trenzyColors.background.withValues(alpha: 0.95),
                      context.trenzyColors.background.withValues(alpha: 0.4),
                      context.trenzyColors.background.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (product.brand != null)
                          _buildTag(product.brand!, Colors.white.withValues(alpha: 0.1)),
                        if (product.brand != null) SizedBox(width: 8),
                        if (product.category != null)
                          _buildTag(product.category!, context.trenzyColors.primary.withValues(alpha: 0.2), textColor: context.trenzyColors.primary),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      product.name,
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    if (product.description != null)
                      Text(
                        product.description!,
                        style: TextStyle(
                          color: context.trenzyColors.mutedFg.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MSRP',
                              style: TextStyle(
                                color: context.trenzyColors.mutedFg,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              product.effectivePrice,
                              style: TextStyle(
                                color: context.trenzyColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push(
                              AppRoutes.productDetailsFor(product.id),
                              extra: ProductDetailsRouteExtra(productId: product.id),
                            );
                          },
                          icon: Icon(Icons.info_outline, size: 18),
                          label: Text(
                            'DETAILS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: context.trenzyColors.foreground,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, {Color textColor = GlassColors.foreground}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls(String groupId) {
    final user = ref.read(auth_p.authProvider).valueOrNull;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.close,
          size: 32,
          color: context.trenzyColors.mutedFg,
          onTap: () => _sendSwipe(groupId, user, SwipeType.dislike),
        ),
        SizedBox(width: 24),
        _buildControlButton(
          icon: Icons.bookmark,
          size: 24,
          color: context.trenzyColors.primary.withValues(alpha: 0.6),
          onTap: () {},
        ),
        SizedBox(width: 24),
        _buildControlButton(
          icon: Icons.favorite,
          size: 44,
          color: context.trenzyColors.primary,
          isFilled: true,
          hasPulse: true,
          onTap: () => _sendSwipe(groupId, user, SwipeType.love),
        ),
      ],
    );
  }

  void _sendSwipe(String groupId, dynamic user, SwipeType type) {
    if (user == null) return;
    final blendGroup = ref.read(blendGroupProvider(groupId)).valueOrNull;
    if (blendGroup == null || blendGroup.options.isEmpty) return;

    final totalSwipes = _liveState?.totalSwipes ?? 0;
    final productIndex = totalSwipes % blendGroup.options.length;
    final product = blendGroup.options[productIndex];

    BlendSocketService.instance.sendSwipe(
      groupId: groupId,
      productId: product.id,
      userId: user.id,
      userName: user.name,
      swipeType: type,
    );

    // Show live feedback snackbar for user's swipe
    if (mounted) {
      final message = type == SwipeType.love 
          ? "❤️ You loved ${product.name}!" 
          : type == SwipeType.like 
              ? "👍 You liked ${product.name}"
              : "👎 You passed on ${product.name}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: type == SwipeType.love 
              ? context.trenzyColors.crimson 
              : type == SwipeType.like 
                  ? context.trenzyColors.primary 
                  : context.trenzyColors.mutedFg,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required Color color,
    bool isFilled = false,
    bool hasPulse = false,
    VoidCallback? onTap,
  }) {
    final double buttonSize = hasPulse ? 80 : (size > 32 ? 64 : 56);

    Widget button = ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: context.trenzyColors.graphite.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasPulse
                    ? context.trenzyColors.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              boxShadow: hasPulse
                  ? [
                      BoxShadow(
                        color: context.trenzyColors.primary.withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              size: size,
              color: color,
              fill: isFilled ? 1.0 : 0.0,
            ),
          ),
        ),
      ),
    );

    if (hasPulse) {
      return PulseGlow(
        minOpacity: 0.6,
        maxOpacity: 1.0,
        minScale: 1.0,
        maxScale: 1.04,
        child: button,
      );
    }
    return button;
  }

  Widget _buildLiveActivityFeed(List<BlendMember> members) {
    // P1: Use _lastSwipeEvent from swipe_applied stream for immediate updates
    final swipeEvent = _lastSwipeEvent;
    final memberNames = members.map((m) => m.userName).toList();

    return GlassBlurredContainer(
      radius: 16,
      blurSigma: 24,
      color: context.trenzyColors.graphite.withValues(alpha: 0.7),
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 54,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.trenzyColors.emerald,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: context.trenzyColors.emerald, blurRadius: 8),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: context.trenzyColors.foreground),
                  children: [
                    if (swipeEvent != null) ...[
                      TextSpan(
                        text: '${swipeEvent['userName'] ?? 'Someone'} ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.trenzyColors.primary),
                      ),
                      TextSpan(
                        text: _getSwipeActionText(swipeEvent['swipeType'] ?? 'liked'),
                      ),
                    ] else ...[
                      TextSpan(
                        text: '${memberNames.isNotEmpty ? memberNames.first : 'Members'} ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.trenzyColors.primary),
                      ),
                      TextSpan(text: ' joined the session'),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Just now',
              style: TextStyle(
                fontSize: 10,
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSwipeActionText(String swipeType) {
    switch (swipeType) {
      case 'love':
        return 'loved this';
      case 'like':
        return 'liked this';
      case 'dislike':
        return 'passed on this';
      default:
        return 'swiped';
    }
  }

  void _handleSocketError(String error) {
    if (!mounted) return;

    // P0 ERROR HANDLING: Distinguish between connection issues and auth failures
    bool isCritical = error.contains('token') ||
        error.contains('expired') ||
        error.contains('revoked') ||
        error.contains('Not authenticated');

    if (isCritical) {
      // Session expired or auth failed - show error and nav to re-auth
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your session expired. Please sign in again.'),
          backgroundColor: Colors.red,
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
      // Transient connection error - user can retry
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: context.trenzyColors.crimson,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: context.trenzyColors.background.withValues(alpha: 0.8),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, Icons.home, 'Home', AppRoutes.home),
                _buildNavItem(context, Icons.style, 'Social', AppRoutes.blendHub),
                _buildNavItem(context, Icons.search, 'Discover', AppRoutes.discover),
                _buildNavItem(context, Icons.checkroom, 'Closet', AppRoutes.wardrobe),
                _buildNavItem(context, Icons.person, 'Profile', AppRoutes.profile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.trenzyColors.mutedFg.withValues(alpha: 0.4), size: 26),
          SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.trenzyColors.mutedFg.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}