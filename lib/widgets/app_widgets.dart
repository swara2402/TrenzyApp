import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../models/blend_model.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';

import 'product_card.dart';

BoxDecoration panelDecoration(
  BuildContext context, {
  List<Color>? gradient,
  double radius = AppRadius.panel,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  // Tonal layering + subtle 1px stroke.
  final stroke = cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35);

  final bg = gradient == null
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  cs.surfaceContainerLow.withValues(alpha: 0.75),
                  cs.surfaceContainer.withValues(alpha: 0.55),
                ]
              : [
                  cs.surfaceContainerLowest.withValues(alpha: 0.92),
                  cs.surfaceContainerLow.withValues(alpha: 0.78),
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
  });

  final IconData? leading;
  final IconData? trailing;
  final VoidCallback onToggleTheme;
  final VoidCallback? onLeadingPressed;
  final VoidCallback? onTrailingPressed;
  final String? title;
  final bool showThemeToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
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
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.primary,
                  fontSize: 20,
                  letterSpacing: 0.15,
                  fontWeight: FontWeight.w800,
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
                  const SizedBox(width: 8),
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
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({this.icon, required this.onPressed});

  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (icon == null) return const SizedBox.shrink();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        iconSize: 20,
        splashRadius: 20,
        color: cs.primary,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autofocus: autoFocus,
              onTap: onTap,
              onSubmitted: onSubmitted,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: hintText ?? 'Search products, brands, vibes...',
                border: InputBorder.none,
                filled: false,
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}

class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    setState(() {
      _scale = pressed ? widget.scaleDown : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
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
    EdgeInsets padding = const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: panelDecoration(
        context,
        radius: AppRadius.sheet,
      ).copyWith(border: Border.all(color: context.cardStroke)),
      child: Column(
        children: [
          // Illustration-style icon with a soft halo.
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.16 : 0.10,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.22 : 0.16,
                ),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 26),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onActionPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
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
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      const Color(0xFF1B1F2B),
                      const Color(0xFF2C3141),
                      const Color(0xFF1B1F2B),
                    ]
                  : [
                      const Color(0xFFF1E8F3),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF1E8F3),
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
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 72,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
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
            color: Theme.of(context).cardColor,
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
    duration: const Duration(milliseconds: 1600),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF163020), const Color(0xFF1B2A1E)]
          : [const Color(0xFFE8F7EC), const Color(0xFFF6FCEB)],
    );
    final border = isDark ? const Color(0xFF2E5B3C) : const Color(0xFFCCEBCB);
    final checkBg = isDark ? const Color(0xFF2E6B41) : const Color(0xFF8FD477);
    final messageColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.7);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: surfaceGradient,
            borderRadius: BorderRadius.circular(AppRadius.sheet),
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
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(
        context,
        radius: 28,
        gradient: isDark
            ? [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                Theme.of(context).colorScheme.surface,
              ]
            : [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.4),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Identity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            identity,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(vibeLine),
          const SizedBox(height: 14),
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
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    trait,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
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
        style: const TextStyle(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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
                          const Color(0xFFF6D7B8),
                          const Color(0xFFDAC7F8),
                          const Color(0xFFBDE7CF),
                          const Color(0xFFE9B7F0),
                        ][index],
                        child: index == 3
                            ? const Text(
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AvatarPoster(
                  imageUrl: products.isNotEmpty ? products[0].imageUrl : null,
                  name: products.isNotEmpty ? products[0].name : null,
                ),
              ),
              const SizedBox(width: 10),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                groupName ?? 'Active Blend',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            memberCount != null && optionCount != null
                ? '$memberCount friends voting on $optionCount options'
                : 'Join the decision',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(12),
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
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
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
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedScale(
      scale: isSelected ? 1.01 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: panelDecoration(context, radius: 30).copyWith(
          border: Border.all(
            color: isSelected
                ? primary
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF0E6F5)),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            ...?panelDecoration(context, radius: 30).boxShadow,
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
                            : const Color(0xFFFFD9EC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        accentLabel,
                        style: const TextStyle(
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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
      duration: const Duration(milliseconds: 220),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  votes,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(compatibility, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
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
    duration: const Duration(milliseconds: 320),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                ? Theme.of(context).cardColor.withValues(alpha: 0.94)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF0E6F5),
            ),
          ),
          child: Text(widget.icon, style: const TextStyle(fontSize: 20)),
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
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : Theme.of(context).cardColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message),
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
          gradient: const LinearGradient(
            colors: [Color(0xFF473E38), Color(0xFFD8CFC7)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            const Center(child: FashionSilhouette(color: Color(0xFFE4D2CE))),
            Positioned(
              right: 12,
              top: 12,
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                child: const Icon(Icons.favorite_border_rounded),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyMedium?.color,
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
    final displayPrice = price?.toStringAsFixed(2) ?? '284.00';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rs $displayPrice',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBuyPressed,
              child: const Text('Buy This Vibe'),
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
      return const FriendlyEmptyState(
        title: 'No vault items',
        message: 'Items you save will appear here.',
        icon: Icons.favorite_rounded,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: effectiveProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.shopping_bag_rounded, size: 38),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.shopping_bag_rounded, size: 38),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.formattedPrice,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
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
        gradient: const LinearGradient(
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(context, radius: 26),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: isDark
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFC78BF8),
          ),
          const SizedBox(height: 10),
          Text(
            'Style Shuffle',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Mix your saved pieces into a fresh new look.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onGenerate ?? () {},
            child: const Text('Generate'),
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
      duration: const Duration(milliseconds: 220),
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
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayGroup = group;
    final displayName = displayGroup?.name ?? 'Vault';

    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF171722), Color(0xFF4B2336)],
              )
            : LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.surfaceContainerLow,
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
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          const Spacer(),
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: isDark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayGroup != null
                ? '${displayGroup.memberCount} members · ${displayGroup.options.length} options'
                : 'Your saved decisions and favorite pieces.',
            style: TextStyle(
              color: isDark
                  ? Colors.white70
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
    final displaySubtitle = subtitle ?? product?.formattedPrice ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(context, radius: 22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: product?.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      product!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.shopping_bag_rounded),
                    ),
                  )
                : const Icon(Icons.shopping_bag_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  displaySubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
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
                    ? ProductCard(product: effectiveProducts[0])
                    : const LargeFeatureCard(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 190,
                decoration: panelDecoration(context, radius: 24),
                child: const Center(
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB98A55), Color(0xFFFEF4DF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 120,
                decoration: panelDecoration(context, radius: 24),
                padding: const EdgeInsets.all(16),
                child: const Center(
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
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
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
    final theme = Theme.of(context);
    final fallbackInitial = name?.isNotEmpty == true
        ? name!.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    fallbackInitial,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                fallbackInitial,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    return Container(
      width: compact ? 168 : null,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        color: theme.colorScheme.surface,
        border: Border.all(color: context.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeletonShimmer(
            height: compact ? 116 : 140,
            radius: AppRadius.input,
          ),
          const SizedBox(height: AppSpacing.sm),
          LoadingSkeletonShimmer(
            height: 14,
            width: double.infinity,
            radius: AppRadius.chip,
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          LoadingSkeletonShimmer(height: 12, width: 70, radius: AppRadius.chip),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: LoadingSkeletonShimmer(
                  height: 16,
                  radius: AppRadius.chip,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              LoadingSkeletonShimmer(height: 24, width: 24, radius: 12),
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
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.cardGap,
          mainAxisSpacing: AppSpacing.cardGap,
          childAspectRatio: 0.72,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => const ProductCardSkeleton(),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                label!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.group_work_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name.isNotEmpty ? group.name : 'Unnamed Blend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberCount} members · ${group.options.length} options',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
          LoadingSkeletonShimmer(height: 60, radius: AppRadius.panel),
          const SizedBox(height: 10),
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
