import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  static const List<NavItem> navItems = [
    NavItem(Icons.shopping_bag_rounded, 'Shop', AppRoutes.home),
    NavItem(Icons.groups_rounded, 'Compare', AppRoutes.blendHub),
    NavItem(Icons.local_fire_department_rounded, 'Trending', AppRoutes.trends),
    NavItem(Icons.favorite_rounded, 'Saved', AppRoutes.wishlist),
    NavItem(Icons.person_rounded, 'Profile', AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: BottomNavBar(
          currentIndex: _indexForLocation(currentLocation),
          onTap: (index) => context.go(navItems[index].route),
        ),
      ),
    );
  }

  int _indexForLocation(String location) {
    for (int i = 0; i < navItems.length; i++) {
      if (location.startsWith(navItems[i].route)) {
        return i;
      }
    }
    return 0;
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final String route;

  const NavItem(this.icon, this.label, this.route);
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.72 : 0.82),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? cs.outlineVariant.withValues(alpha: 0.25)
                    : cs.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < AppShell.navItems.length; i++)
                  Expanded(
                    child: _NavItemButton(
                      item: AppShell.navItems[i],
                      isActive: currentIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemButton extends StatelessWidget {
  const _NavItemButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isActive
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFontsForAppShell.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              // Animated active indicator with spring physics.
              AnimatedOpacity(
                opacity: isActive ? 1 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.only(top: 4),
                  height: isActive ? 3 : 3,
                  width: isActive ? 16 : 14,
                  transformAlignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaled(isActive ? 1.0 : 0.75, isActive ? 1.0 : 0.75, 1.0),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal local helper so app_shell.dart doesn't depend on google_fonts
/// while still using Plus Jakarta Sans for the nav labels.
class GoogleFontsForAppShell {
  static TextStyle plusJakartaSans({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
