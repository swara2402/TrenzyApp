import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../models/blend_model.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';
import 'product_card.dart';

BoxDecoration panelDecoration(
  BuildContext context, {
  List<Color>? gradient,
  double radius = GlassRadius.panel,
}) {
  final isDark = context.isDark;

  // Tonal layering + subtle 1px stroke.
  final stroke = context.trenzyColors.glassBorder.withValues(alpha: isDark ? 0.2 : 0.35);

  final bg = gradient == null
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  context.trenzyColors.graphite.withValues(alpha: 0.75),
                  context.trenzyColors.graphite.withValues(alpha: 0.55),
                ]
              : [
                  context.trenzyColors.background.withValues(alpha: 0.92),
                  context.trenzyColors.graphite.withValues(alpha: 0.78),
                ],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        );

  return BoxDecoration(
    gradient: bg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: stroke, width: 1),
  );
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.leading,
    this.trailing,
    required this.onToggleTheme,
    this.onLeadingPressed,
    this.onTrailingPressed,
    this.title,
    this.showThemeToggle = true,
    this.sliver = true,
  });

  final IconData? leading;
  final IconData? trailing;
  final VoidCallback onToggleTheme;
  final VoidCallback? onLeadingPressed;
  final VoidCallback? onTrailingPressed;
  final String? title;
  final bool showThemeToggle;
  final bool sliver;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final result = Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          16,
          AppSpacing.containerMargin,
          8,
        ),
        child: Row(
          children: [
            if (leading != null)
              _TopBarButton(
                icon: leading,
                onPressed:
                    onLeadingPressed ?? () => context.push(AppRoutes.home),
              )
            else
              _TopBarButton(
                icon: Icons.menu_rounded,
                onPressed: onLeadingPressed ?? () {},
              ),
            Expanded(
              child: Text(
                title ?? 'TRENZY',
                textAlign: TextAlign.center,
                style: GlassTypography.body(
                  fontSize: 20,
                  color: context.trenzyColors.primary,
                  weight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null)
                  _TopBarButton(
                    icon: trailing,
                    onPressed:
                        onTrailingPressed ??
                        () => context.push(AppRoutes.profile),
                  )
                else
                  _TopBarButton(
                    icon: Icons.notifications_outlined,
                    onPressed: onTrailingPressed ?? () {},
                  ),
                if (showThemeToggle) ...[
                  SizedBox(width: 8),
                  _TopBarButton(
                    icon: isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    onPressed: onToggleTheme,
                  ),
                ],
              ],
            ),
            ],
          ),
    );
    if (sliver) {
      return SliverToBoxAdapter(child: result);
    }
    return result;
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({this.icon, required this.onPressed});

  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: context.trenzyColors.glassBorder.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        iconSize: 20,
        splashRadius: 20,
        color: context.trenzyColors.primary,
        icon: Icon(icon),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.onTap,
    this.onSubmitted,
    this.hintText,
    this.readOnly = false,
    this.autoFocus = false,
  });

  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool readOnly;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(GlassRadius.input),
        border: Border.all(color: context.trenzyColors.glassBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: context.trenzyColors.mutedFg),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autofocus: autoFocus,
              onTap: onTap,
              onSubmitted: onSubmitted,
              style: TextStyle(color: context.trenzyColors.foreground),
              decoration: InputDecoration(
                hintText: hintText ?? 'Search products, brands, vibes...',
                border: InputBorder.none,
                filled: false,
                hintStyle: GlassTypography.body(color: context.trenzyColors.fg50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GlassTypography.body(
              fontSize: 20,
              weight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(
                color: context.trenzyColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}

class FriendlyEmptyState extends StatelessWidget {
  const FriendlyEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_rounded,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  static Widget buildSliver({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.auto_awesome_rounded,
    EdgeInsets padding = const EdgeInsets.all(AppSpacing.md),
  }) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(
        child: FriendlyEmptyState(title: title, message: message, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        GlassSpacing.lg,
        GlassSpacing.xl,
        GlassSpacing.lg,
        GlassSpacing.xl,
      ),
      decoration: panelDecoration(
        context,
        radius: GlassRadius.sheet,
      ).copyWith(border: Border.all(color: context.cardStroke)),
      child: Column(
        children: [
          // Illustration-style icon with a soft halo.
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.trenzyColors.primary.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.primary.withValues(alpha: 0.22),
              ),
              child: Icon(icon, color: context.trenzyColors.primary, size: 26),
            ),
          ),
          SizedBox(height: GlassSpacing.lg),
          Text(
            title,
            style: GlassTypography.body(
              fontSize: 20,
              weight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: GlassSpacing.sm),
          Text(
            message,
            style: GlassTypography.body(
              fontSize: 14,
              color: context.trenzyColors.fg50,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            SizedBox(height: GlassSpacing.lg),
            FilledButton.icon(
              onPressed: onActionPressed,
              icon: Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedShimmer extends StatefulWidget {
  const _AnimatedShimmer({required this.child});

  final Widget child;

  @override
  State<_AnimatedShimmer> createState() => _AnimatedShimmerState();
}

class _AnimatedShimmerState extends State<_AnimatedShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final start = -1 + (_controller.value * 2);
        final end = start + 1.2;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(start, -0.4),
              end: Alignment(end, 0.4),
              colors: isDark
                  ? [
                      Color(0xFF1B1F2B),
                      Color(0xFF2C3141),
                      Color(0xFF1B1F2B),
                    ]
                  : [
                      Color(0xFFF1E8F3),
                      Color(0xFFFFFFFF),
                      Color(0xFFF1E8F3),
                    ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SuggestionLoadingState extends StatelessWidget {
  const SuggestionLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Finding options that match your vibe...',
          style: GlassTypography.body(fontSize: 16, weight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: GlassSpacing.md),
        for (var index = 0; index < 2; index++) ...[
          _AnimatedShimmer(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: panelDecoration(context, radius: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: index == 0 ? 220 : 165,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.glass,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  SizedBox(height: GlassSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: context.trenzyColors.glass,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        width: 72,
                        height: 18,
                        decoration: BoxDecoration(
                          color: context.trenzyColors.glass,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: GlassSpacing.xs),
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.glass,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: GlassSpacing.xs),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.glass,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  SizedBox(height: GlassSpacing.sm),
                  Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.trenzyColors.glass,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: GlassSpacing.sm),
        ],
      ],
    );
  }
}

class AsyncRetryErrorState extends StatelessWidget {
  const AsyncRetryErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    required this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(GlassSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.trenzyColors.primary),
            SizedBox(height: GlassSpacing.sm),
            Text(
              title,
              style: GlassTypography.body(
                fontSize: 16,
                weight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: GlassSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: GlassSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingSkeletonShimmer extends StatelessWidget {
  const LoadingSkeletonShimmer({
    super.key,
    required this.height,
    this.width,
    this.radius = 22,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
      return SizedBox(
        width: width,
        height: height,
        child: _AnimatedShimmer(
          child: Container(
            width: width ?? double.infinity,
            decoration: BoxDecoration(
              color: context.trenzyColors.glass,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      );
  }
}

class SuccessPulseBanner extends StatefulWidget {
  const SuccessPulseBanner({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<SuccessPulseBanner> createState() => _SuccessPulseBannerState();
}

class _SuccessPulseBannerState extends State<SuccessPulseBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    final isDark = context.isDark;

    final surfaceGradient = LinearGradient(
      colors: isDark
          ? [Color(0xFF163020), Color(0xFF1B2A1E)]
          : [Color(0xFFE8F7EC), Color(0xFFF6FCEB)],
    );
    final border = isDark ? Color(0xFF2E5B3C) : Color(0xFFCCEBCB);
    final checkBg = isDark ? Color(0xFF2E6B41) : Color(0xFF8FD477);
    final messageColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.7);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(GlassSpacing.lg),
          decoration: BoxDecoration(
            gradient: surfaceGradient,
            borderRadius: BorderRadius.circular(GlassRadius.sheet),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: checkBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(width: GlassSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GlassTypography.body(
                        fontSize: 16,
                        weight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: GlassSpacing.xxs),
                    Text(
                      widget.message,
                      style: GlassTypography.body(
                        fontSize: 14,
                        color: messageColor,
                      ),
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
}

class StyleIdentityCard extends StatelessWidget {
  const StyleIdentityCard({
    super.key,
    required this.identity,
    required this.vibeLine,
    required this.traits,
  });

  final String identity;
  final String vibeLine;
  final List<String> traits;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(
        context,
        radius: 28,
        gradient: isDark
            ? [
                context.trenzyColors.primary.withValues(alpha: 0.18),
                context.trenzyColors.graphite,
              ]
            : [
                context.trenzyColors.primary.withValues(alpha: 0.10),
                context.trenzyColors.primary.withValues(alpha: 0.15),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Identity',
            style: GlassTypography.body(
              fontSize: 14,
              weight: FontWeight.w800,
              color: context.trenzyColors.primary,
            ),
          ),
          SizedBox(height: GlassSpacing.xs),
          Text(
            identity,
            style: GlassTypography.display(
              fontSize: 24,
              weight: FontWeight.w900,
            ),
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(vibeLine, style: GlassTypography.body()),
          SizedBox(height: GlassSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final trait in traits)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.trenzyColors.glass.withValues(alpha: 0.5)
                        : context.trenzyColors.primary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    trait,
                    style: GlassTypography.body(
                      fontSize: 11,
                      weight: FontWeight.w700,
                      color: context.trenzyColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MoodChip extends StatelessWidget {
  const MoodChip({super.key, required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    this.products = const [],
    this.groupName = 'Gala',
  });

  final List<ProductModel> products;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Choosing for "$groupName"',
                  style: GlassTypography.body(
                    fontSize: 16,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 74,
                height: 24,
                child: Stack(
                  children: List.generate(
                    4,
                    (index) => Positioned(
                      left: index * 16,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: [
                          Color(0xFFF6D7B8),
                          Color(0xFFDAC7F8),
                          Color(0xFFBDE7CF),
                          Color(0xFFE9B7F0),
                        ][index],
                        child: index == 3
                            ? Text(
                                '+1',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            '4 friends voting now',
            style: GlassTypography.body(
              fontSize: 12,
              color: context.trenzyColors.mutedFg,
            ),
          ),
          SizedBox(height: GlassSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AvatarPoster(
                  imageUrl: products.isNotEmpty ? products[0].imageUrl : null,
                  name: products.isNotEmpty ? products[0].name : null,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: AvatarPoster(
                  imageUrl: products.length > 1 ? products[1].imageUrl : null,
                  name: products.length > 1 ? products[1].name : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniLiveCard extends StatelessWidget {
  const MiniLiveCard({
    super.key,
    this.groupName,
    this.memberCount,
    this.optionCount,
  });

  final String? groupName;
  final int? memberCount;
  final int? optionCount;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: EdgeInsets.all(GlassSpacing.md),
      decoration: panelDecoration(
        context,
        radius: 26,
        gradient: isDark
            ? const [Color(0xFF163120), Color(0xFF1E3A28)]
            : const [Color(0xFFE1F6E3), Color(0xFFF2FBF4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.shade800 : Colors.green.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                groupName ?? 'Active Blend',
                style: GlassTypography.body(
                  fontSize: 14,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(
            memberCount != null && optionCount != null
                ? '$memberCount friends voting on $optionCount options'
                : 'Join the decision',
            style: GlassTypography.body(
              fontSize: 14,
              color: context.trenzyColors.foreground.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: GlassSpacing.sm),
          Center(
            child: Icon(
              Icons.compare_arrows_rounded,
              size: 28,
              color: isDark ? Colors.green.shade400 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class TrendCard extends StatelessWidget {
  const TrendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.badge,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String badge;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(GlassSpacing.sm),
      decoration: panelDecoration(context, radius: 24, gradient: gradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              child: Icon(icon, size: 16, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: GlassSpacing.xs),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: GlassSpacing.xxs),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductHeroCard extends StatelessWidget {
  const ProductHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.accentLabel,
    required this.gradient,
    required this.silhouetteColor,
    required this.buttonLabel,
    this.compact = false,
    this.isSelected = false,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String price;
  final String accentLabel;
  final List<Color> gradient;
  final Color silhouetteColor;
  final String buttonLabel;
  final bool compact;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.01 : 1,
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: panelDecoration(context, radius: 30).copyWith(
          border: Border.all(
            color: isSelected
                ? context.trenzyColors.primary
                : (context.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Color(0xFFF0E6F5)),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            ...?panelDecoration(context, radius: 30).boxShadow,
            if (isSelected)
              BoxShadow(
                color: context.trenzyColors.primary.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: compact ? 165 : 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
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
                      child: Text(
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
                      duration: Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.94)
                            : Color(0xFFFFD9EC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        accentLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Center(child: FashionSilhouette(color: silhouetteColor)),
                ],
              ),
            ),
            SizedBox(height: GlassSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GlassTypography.body(
                      fontSize: 20,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  price,
                  style: GlassTypography.body(
                    fontSize: 20,
                    weight: FontWeight.w800,
                    color: context.trenzyColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: GlassSpacing.xxs),
            Text(
              subtitle,
              style: GlassTypography.body(
                fontSize: 14,
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
              ),
            ),
            if (isSelected) ...[
              SizedBox(height: GlassSpacing.xs),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: context.trenzyColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Selected for comparison',
                    style: GlassTypography.body(
                      fontSize: 12,
                      color: context.trenzyColors.primary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: GlassSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TapScale(
                child: FilledButton(
                  onPressed: onPressed,
                  child: Text(buttonLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FashionSilhouette extends StatelessWidget {
  const FashionSilhouette({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            child: CircleAvatar(radius: 18, backgroundColor: color),
          ),
          Positioned(
            top: 38,
            child: Container(
              width: 68,
              height: 88,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            top: 52,
            left: 5,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 22,
                height: 70,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Positioned(
            top: 52,
            right: 5,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 22,
                height: 70,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 28,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                width: 18,
                height: 74,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 28,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 18,
                height: 74,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoteCard extends StatelessWidget {
  const VoteCard({
    super.key,
    required this.option,
    required this.price,
    required this.votes,
    required this.compatibility,
    required this.gradient,
    required this.silhouetteColor,
    this.buttonLabel,
    this.onPressed,
  });

  final String option;
  final String price;
  final String votes;
  final String compatibility;
  final List<Color> gradient;
  final Color silhouetteColor;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(10),
      decoration: panelDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: FashionSilhouette(color: silhouetteColor)),
          ),
          SizedBox(height: GlassSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: GlassTypography.body(
                    fontSize: 16,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.trenzyColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: GlassSpacing.xxs),
          Row(
            children: [
              Expanded(
                child: Text(
                  votes,
                  style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
                ),
              ),
              Text(compatibility, style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg)),
            ],
          ),
          SizedBox(height: GlassSpacing.sm),
          if (buttonLabel != null)
            SizedBox(
              width: double.infinity,
              child: TapScale(
                child: OutlinedButton(
                  onPressed: onPressed,
                  child: Text(buttonLabel!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReactionChip extends StatefulWidget {
  const ReactionChip({super.key, required this.icon});

  final String icon;

  @override
  State<ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 320),
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return GestureDetector(
      onTap: () async {
        await _controller.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale =
              1 + (0.12 * Curves.elasticOut.transform(_controller.value));
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? context.trenzyColors.glass.withValues(alpha: 0.94)
                : context.trenzyColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Color(0xFFF0E6F5),
            ),
          ),
          child: Text(widget.icon, style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.dotColor,
  });

  final String name;
  final String subtitle;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: dotColor),
      title: Text(name, style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.highlight});

  final String message;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight
              ? context.trenzyColors.primary.withValues(alpha: 0.18)
              : context.trenzyColors.glass.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message, style: GlassTypography.body()),
      ),
    );
  }
}

class LargeFeatureCard extends StatelessWidget {
  const LargeFeatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: panelDecoration(context, radius: 28),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF473E38), Color(0xFFD8CFC7)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Center(child: FashionSilhouette(color: Color(0xFFE4D2CE))),
            Positioned(
              right: 12,
              top: 12,
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                child: Icon(Icons.favorite_border_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? tint.withValues(alpha: 0.18) : tint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : tint.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GlassTypography.meta(color: context.trenzyColors.mutedFg),
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(
            value,
            style: GlassTypography.body(
              weight: FontWeight.w800,
              color: context.trenzyColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class PricePanel extends StatelessWidget {
  const PricePanel({super.key, this.price, this.onBuyPressed});

  final double? price;
  final VoidCallback? onBuyPressed;

  @override
  Widget build(BuildContext context) {
    final displayPrice = price == null ? 'Price unavailable' : '₹${price!.toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayPrice,
            style: GlassTypography.display(fontSize: 24, weight: FontWeight.w800),
          ),
          SizedBox(height: GlassSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBuyPressed,
              child: Text('Buy This Vibe'),
            ),
          ),
        ],
      ),
    );
  }
}

class GridMiniCards extends StatelessWidget {
  const GridMiniCards({super.key, this.products});

  final List<ProductModel>? products;

  @override
  Widget build(BuildContext context) {
    final effectiveProducts = products ?? const [];
    if (effectiveProducts.isEmpty) {
      return FriendlyEmptyState(
        title: 'No vault items',
        message: 'Items you save will appear here.',
        icon: Icons.favorite_rounded,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: effectiveProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final product = effectiveProducts[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: panelDecoration(context, radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.trenzyColors.graphite,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child:
                      product.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: product.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Center(
                              child: Icon(Icons.shopping_bag_rounded, size: 38),
                            ),
                            errorWidget: (_, _, _) => Center(
                              child: Icon(Icons.shopping_bag_rounded, size: 38),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.shopping_bag_rounded, size: 38),
                        ),
                ),
              ),
              SizedBox(height: GlassSpacing.xs),
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.effectivePrice.toString(),
                style: TextStyle(
                  color: context.trenzyColors.primary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RelatedVibeBanner extends StatelessWidget {
  const RelatedVibeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6D2BD), Color(0xFFDFB07B)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Midnight Gala',
                style: GlassTypography.body(
                  fontSize: 20,
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ),
              SizedBox(height: GlassSpacing.xxs),
              Text(
                'For your saved evening edit',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StyleShufflerCard extends StatelessWidget {
  const StyleShufflerCard({super.key, this.onGenerate});

  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(context, radius: 26),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: isDark
                ? context.trenzyColors.primary
                : Color(0xFFC78BF8),
          ),
          SizedBox(height: GlassSpacing.xs),
          Text(
            'Style Shuffle',
            style: GlassTypography.body(
              fontSize: 16,
              weight: FontWeight.w800,
            ),
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(
            'Mix your saved pieces into a fresh new look.',
            textAlign: TextAlign.center,
            style: GlassTypography.body(fontSize: 14),
          ),
          SizedBox(height: GlassSpacing.sm),
          FilledButton(
            onPressed: onGenerate ?? () {},
            child: Text('Generate'),
          ),
        ],
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      decoration: panelDecoration(context, radius: 22),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class VaultBanner extends StatelessWidget {
  const VaultBanner({super.key, this.group, this.isActive = false});

  final BlendGroup? group;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final displayGroup = group;
    final displayName = displayGroup?.name ?? 'Vault';

    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [Color(0xFF171722), Color(0xFF4B2336)],
              )
            : LinearGradient(
                colors: [
                  context.trenzyColors.background.withValues(alpha: 0.8),
                  context.trenzyColors.graphite,
                ],
              ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          Spacer(),
          Text(
            displayName,
            style: GlassTypography.display(
              fontSize: 24,
              color: isDark
                  ? Colors.white
                  : context.trenzyColors.foreground,
              weight: FontWeight.w800,
            ),
          ),
          SizedBox(height: GlassSpacing.xxs),
          Text(
            displayGroup != null
                ? '${displayGroup.memberCount} members · ${displayGroup.options.length} options'
                : 'Your saved decisions and favorite pieces.',
            style: GlassTypography.body(
              color: isDark
                  ? Colors.white70
                  : context.trenzyColors.foreground.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class SlimArchiveCard extends StatelessWidget {
  const SlimArchiveCard({super.key, this.title, this.subtitle, this.product});

  final String? title;
  final String? subtitle;
  final ProductModel? product;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? product?.name ?? 'Item';
    final displaySubtitle = subtitle ??
        (product?.effectivePrice != null ? '\$${product!.effectivePrice.toStringAsFixed(2)}' : '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(context, radius: 22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: context.trenzyColors.graphite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: product?.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: product!.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Icon(Icons.shopping_bag_rounded),
                      errorWidget: (_, _, _) =>
                          Icon(Icons.shopping_bag_rounded),
                    ),
                  )
                : Icon(Icons.shopping_bag_rounded),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: GlassSpacing.xxs),
                Text(
                  displaySubtitle,
                  style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DecisionShowcase extends StatelessWidget {
  const DecisionShowcase({super.key, this.products});

  final List<ProductModel>? products;

  @override
  Widget build(BuildContext context) {
    final effectiveProducts = products ?? const [];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 190,
                child: effectiveProducts.isNotEmpty
                    ? ProductCard(
                        product: effectiveProducts[0],
                        heroTagSuffix: '_featured_0',
                      )
                    : LargeFeatureCard(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 190,
                decoration: panelDecoration(context, radius: 24),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    size: 68,
                    color: Color(0xFFC8A4D8),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: GlassSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB98A55), Color(0xFFFEF4DF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 120,
                decoration: panelDecoration(context, radius: 24),
                padding: EdgeInsets.all(GlassSpacing.md),
                child: Center(
                  child: Text(
                    'AI predicted your next summer vibe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: panelDecoration(context, radius: 20),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: onTap,
              leading: CircleAvatar(
                backgroundColor: context.trenzyColors.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: context.trenzyColors.primary),
              ),
              title: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
      );
  }
}

class AvatarPoster extends StatelessWidget {
  const AvatarPoster({super.key, this.imageUrl, this.name});

  final String? imageUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final fallbackInitial = name?.isNotEmpty == true
        ? name!.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(GlassRadius.card),
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(GlassRadius.card),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                placeholder: (_, _) => Center(
                  child: Text(
                    fallbackInitial,
                    style: GlassTypography.body(
                      fontSize: 32,
                      weight: FontWeight.bold,
                      color: context.trenzyColors.fg50,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                fallbackInitial,
                style: GlassTypography.body(
                  fontSize: 32,
                  weight: FontWeight.bold,
                  color: context.trenzyColors.fg50,
                ),
              ),
            ),
    );
  }
}

/// A single product-card-shaped skeleton that visually matches [ProductCard].
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 168 : null,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassRadius.card),
        color: context.trenzyColors.background,
        border: Border.all(color: context.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeletonShimmer(
            height: compact ? 104 : 108,
            radius: GlassRadius.input,
          ),
          SizedBox(height: 6),
          LoadingSkeletonShimmer(
            height: 12,
            width: double.infinity,
            radius: GlassRadius.chip,
          ),
          SizedBox(height: 4),
          LoadingSkeletonShimmer(height: 10, width: 70, radius: GlassRadius.chip),
          SizedBox(height: GlassSpacing.sm),
          Row(
            children: [
              Expanded(
                child: LoadingSkeletonShimmer(
                  height: 14,
                  radius: GlassRadius.chip,
                ),
              ),
              SizedBox(width: 6),
              LoadingSkeletonShimmer(height: 20, width: 20, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// A grid of [ProductCardSkeleton]s for full-screen loading states,
/// avoiding infinite full-screen spinners.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
  });

  final int crossAxisCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    // GridView needs a bounded height when used inside other layouts
    // (e.g. Column / other scrollables). Without it Flutter throws:
    // "Vertical viewport was given unbounded height".
    // Approximate skeleton height to bound the grid. This keeps layout stable
    // across web and prevents infinite-height viewport assertions.
    const double cardOuterVerticalPadding =
        2 * AppSpacing.sm; // ~ padding inside ProductCardSkeleton
    const double skeletonImageHeight =
        140; // ProductCardSkeleton uses 140 for compact=false
    const double skeletonTextBlocksHeight =
        14 + (AppSpacing.sm) + 12 + (AppSpacing.sm); // heuristic
    const double skeletonTotal =
        cardOuterVerticalPadding +
        skeletonImageHeight +
        skeletonTextBlocksHeight +
        28;

    final int rows = (itemCount / crossAxisCount).ceil();
    final double gridHeight =
        rows * skeletonTotal +
        (rows - 1) * AppSpacing.cardGap +
        (2 * AppSpacing.md); // add GridView padding

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.cardGap,
          mainAxisSpacing: AppSpacing.cardGap,
          childAspectRatio: 0.72,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => ProductCardSkeleton(),
      ),
    );
  }
}

/// A small, accessible inline loading indicator for tight spaces
/// (replaces jarring full-screen CircularProgressIndicator usages).
class InlineLoading extends StatelessWidget {
  const InlineLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GlassSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(context.trenzyColors.primary),
              ),
            ),
            if (label != null) ...[
              SizedBox(height: GlassSpacing.md),
              Text(
                label!,
                style: GlassTypography.body(
                  fontSize: 14,
                  color: context.trenzyColors.fg50,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DecisionHistoryCard extends StatelessWidget {
  const DecisionHistoryCard({super.key, required this.group, this.onTap});

  final BlendGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: panelDecoration(context, radius: 22),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark
                    ? context.trenzyColors.graphite
                    : context.trenzyColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.group_work_rounded,
                color: context.trenzyColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name.isNotEmpty ? group.name : 'Unnamed Blend',
                    style: GlassTypography.body(
                      fontSize: 16,
                      weight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: GlassSpacing.xxs),
                  Text(
                    '${group.memberCount} members · ${group.options.length} options',
                    style: GlassTypography.body(
                      fontSize: 12,
                      color: context.trenzyColors.foreground.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.trenzyColors.foreground.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class DecisionShowcaseLoading extends StatelessWidget {
  const DecisionShowcaseLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          LoadingSkeletonShimmer(height: 60, radius: GlassRadius.panel),
          SizedBox(height: GlassSpacing.xs),
        ],
      ],
    );
  }
}

class DecisionShowcaseFallback extends StatelessWidget {
  const DecisionShowcaseFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return FriendlyEmptyState(
      title: 'No decisions yet',
      message: 'Your blend history will appear here after you make selections.',
      icon: Icons.history_rounded,
    );
  }
}
