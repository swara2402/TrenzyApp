import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';

/// v1.0 Press Scale Animation — Frozen Specification
/// Scale: 1 → 0.97 → 1
/// Duration: 120ms
/// Use on all interactive elements (cards, buttons, chips)
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.enableHaptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enableHaptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.press, // 120ms
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.97,
        ).chain(CurveTween(curve: AppCurves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.97,
          end: 1.0,
        ).chain(CurveTween(curve: AppCurves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// v1.0 Staggered Fade + Slide Animation — Frozen Specification
/// Entry: Fade + Slide Up 16px
/// Delay: index × 35ms
/// Duration: 350ms
/// Only first load.
class StaggeredFadeSlide extends StatefulWidget {
  const StaggeredFadeSlide({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = 35,
    this.duration,
  });

  final Widget child;
  final int index;
  final int staggerDelay; // milliseconds between each item (v1.0: 35ms)
  final Duration? duration;

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppDurations.slow, // 350ms
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: AppCurves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.04), // ~16px
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 1.0, curve: AppCurves.easeOutCubic),
          ),
        );

    // Delay animation start based on index (v1.0: index × 35ms)
    Future.delayed(
      Duration(milliseconds: widget.index * widget.staggerDelay),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
