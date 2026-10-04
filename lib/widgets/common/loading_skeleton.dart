/// Loading skeleton and shimmer effects for smooth loading states
///
/// Replaces blank screens with skeleton loaders that match the content layout,
/// providing a smoother perceived load time.
library;

import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';

/// Full-screen skeleton loader with shimmer effect
/// 
/// Use this when loading primary content (home, search results, product details).
/// Provides visual feedback that content is loading, not a blank screen.
class SkeletonLoader extends StatefulWidget {
  /// Number of skeleton items to show
  final int itemCount;

  /// Height of each skeleton item
  final double itemHeight;

  /// Spacing between items
  final double spacing;

  /// Custom child builder for skeleton layout
  /// If provided, [itemCount] and [itemHeight] are ignored
  final Widget? Function(BuildContext, int)? itemBuilder;

  /// Use compact skeleton for secondary content
  final bool compact;

  const SkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 100,
    this.spacing = 12,
    this.itemBuilder,
    this.compact = false,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.itemBuilder != null ? 10 : widget.itemCount,
      separatorBuilder: (_, _) => SizedBox(height: widget.spacing),
      itemBuilder: (context, index) {
        if (widget.itemBuilder != null) {
          return _ShimmerItem(
            animation: _animationController,
            child: widget.itemBuilder!(context, index),
          );
        }

        if (widget.compact) {
          return _CompactSkeletonItem(animation: _animationController);
        }

        return _SkeletonItem(
          animation: _animationController,
          height: widget.itemHeight,
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}

/// Individual skeleton item with shimmer effect
class _SkeletonItem extends StatelessWidget {
  final Animation<double> animation;
  final double height;

  const _SkeletonItem({
    required this.animation,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerItem(
      animation: animation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Container(
            height: height * 0.65,
            decoration: BoxDecoration(
              color: context.trenzyColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          // Title skeleton
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: context.trenzyColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle skeleton
          Container(
            height: 12,
            width: double.maxFinite * 0.7,
            decoration: BoxDecoration(
              color: context.trenzyColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact skeleton for list items
class _CompactSkeletonItem extends StatelessWidget {
  final Animation<double> animation;

  const _CompactSkeletonItem({required this.animation});

  @override
  Widget build(BuildContext context) {
    return _ShimmerItem(
      animation: animation,
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.trenzyColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name skeleton
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.trenzyColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // Description skeleton
                Container(
                  height: 12,
                  width: double.maxFinite * 0.8,
                  decoration: BoxDecoration(
                    color: context.trenzyColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer effect overlay
class _ShimmerItem extends StatelessWidget {
  final Animation<double> animation;
  final Widget? child;

  const _ShimmerItem({
    required this.animation,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                animation.value - 0.3,
                animation.value,
                animation.value + 0.3,
              ],
              colors: [
                context.trenzyColors.surfaceContainer,
                context.trenzyColors.surfaceContainer,
                context.trenzyColors.surfaceContainer,
              ],
            ).createShader(bounds);
          },
          child: this.child,
        );
      },
      child: child,
    );
  }
}

/// Inline shimmer for small widgets while loading
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                context.trenzyColors.surfaceContainer,
                context.trenzyColors.surfaceContainer,
                context.trenzyColors.surfaceContainer,
              ],
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: context.trenzyColors.surfaceContainer,
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
            ),
          ),
        );
      },
    );
  }
}