import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../providers/wishlist_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String? label;
  final String route;
  final bool isCenter;

  GlassNavItem(
    this.icon,
    this.activeIcon,
    this.label,
    this.route, {
    this.isCenter = false,
  });
}

final List<GlassNavItem> appNavItems = [
  GlassNavItem(Icons.home_outlined, Icons.home_rounded, 'Feed', AppRoutes.home),
  GlassNavItem(Icons.explore_outlined, Icons.explore_rounded, 'Explore', AppRoutes.discover),
  GlassNavItem(Icons.currency_exchange_outlined, Icons.currency_exchange_rounded, null, AppRoutes.blendHub, isCenter: true),
  GlassNavItem(Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Wishlist', AppRoutes.wishlist),
  GlassNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', AppRoutes.profile),
];

class _GlassOfflineBannerState extends ConsumerState<_GlassOfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
  }

  void _setupConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: context.trenzyColors.crimson.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          width: double.infinity,
          child: Text(
            'You are offline',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _GlassOfflineBanner extends ConsumerStatefulWidget {
  const _GlassOfflineBanner();

  @override
  ConsumerState<_GlassOfflineBanner> createState() => _GlassOfflineBannerState();
}

class _GlassBottomNavBarState extends ConsumerState<GlassBottomNavBar>
    with TickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.trenzyColors.glassDock,
            border: Border(
              top: BorderSide(color: context.trenzyColors.glassBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: appNavItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = widget.currentIndex == index;
                if (item.isCenter) {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: GlassGradients.primary,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: context.trenzyColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: item.label ?? 'Blends',
                      icon: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: context.trenzyColors.primaryFg,
                        size: 28,
                      ),
                      onPressed: () => widget.onTap(index),
                    ),
                  );
                }
                return IconButton(
                  tooltip: item.label ?? 'Tab',
                  icon: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? context.trenzyColors.primary : context.trenzyColors.mutedFg,
                    size: 28,
                  ),
                  onPressed: () => widget.onTap(index),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassBottomNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  ConsumerState<GlassBottomNavBar> createState() => _GlassBottomNavBarState();
}

class GlassAppShell extends ConsumerWidget {
  const GlassAppShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  static int _indexForLocation(String location) {
    for (int i = 0; i < appNavItems.length; i++) {
      if (location.startsWith(appNavItems[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedCount = ref.watch(
      wishlistProvider.select((w) => w.valueOrNull?.productIds.length ?? 0),
    );
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      extendBody: true,
      body: Stack(
        children: [
          child,
          Positioned(top: 0, left: 0, right: 0, child: _GlassOfflineBanner()),
          if (savedCount > 0)
            Positioned(
              bottom: 100,
              right: 16,
              child: Tooltip(
                message: 'View saved picks ($savedCount)',
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.wishlist),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: GlassGradients.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.trenzyColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.bookmark_rounded, color: context.trenzyColors.primaryFg, size: 24),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.trenzyColors.crimson,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              savedCount > 9 ? '9+' : '$savedCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: GlassBottomNavBar(
          currentIndex: _indexForLocation(currentLocation),
          onTap: (index) => context.go(appNavItems[index].route),
        ),
      ),
    );
  }
}