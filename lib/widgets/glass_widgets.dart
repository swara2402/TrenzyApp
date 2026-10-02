import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/glass_theme.dart';

/// An ambient animated gradient background that adds depth to any screen.
/// Place it as the bottom-most widget in a Stack.
class AmbientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? auraColors;
  final List<Alignment>? auraAlignments;
  final List<double>? auraSizes;
  final bool subtle;

  const AmbientBackground({
    super.key,
    required this.child,
    this.auraColors,
    this.auraAlignments,
    this.auraSizes,
    this.subtle = false,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auras =
        widget.auraColors ??
        [
          context.trenzyColors.primary.withValues(
            alpha: widget.subtle ? 0.04 : 0.08,
          ),
          context.trenzyColors.emerald.withValues(
            alpha: widget.subtle ? 0.03 : 0.06,
          ),
          context.trenzyColors.crimson.withValues(
            alpha: widget.subtle ? 0.02 : 0.04,
          ),
        ];

    final alignments =
        widget.auraAlignments ??
        const [
          Alignment(-0.5, -0.3),
          Alignment(0.7, 0.4),
          Alignment(0.2, -0.6),
        ];

    final sizes = widget.auraSizes ?? [350.0, 280.0, 220.0];

    return Stack(
      children: [
        // Base dark background
        Container(color: context.trenzyColors.background),
        // Animated gradient auras
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: List.generate(auras.length, (i) {
                final alignment = alignments[i];
                final size = sizes[i];
                final wobble = math.sin(
                  (_controller.value * 2 * math.pi) + (i * 2.094),
                );
                final dx = alignment.x + wobble * 0.12;
                final dy = alignment.y + wobble * 0.08;

                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(dx, dy),
                          radius: size / 500,
                          colors: [
                            auras[i],
                            auras[i].withValues(
                              alpha:
                                  (auras[i].a * 255.0 * 0.3).round().clamp(
                                    0,
                                    255,
                                  ) /
                                  255.0,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        // Subtle noise overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.015,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool clip;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final bool glowing;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 28,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
    this.clip = true,
    this.boxShadow,
    this.gradient,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );

    final shadow = glowing ? [GlassShadows.glow, ...?boxShadow] : boxShadow;

    Widget result = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? context.trenzyColors.glassBorder,
          width: 1,
        ),
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.trenzyColors.foreground.withValues(alpha: 0.08),
                context.trenzyColors.foreground.withValues(alpha: 0.03),
              ],
            ),
        boxShadow: shadow,
      ),
      child: clip ? content : child,
    );

    if (onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: result,
      );
    }

    return result;
  }
}

class GlassBlurredContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final bool glowing;

  const GlassBlurredContainer({
    super.key,
    required this.child,
    this.radius = 28,
    this.blurSigma = 24,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.boxShadow,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final shadow = glowing ? [GlassShadows.glow, ...?boxShadow] : boxShadow;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? context.trenzyColors.glassBorder,
          width: 1,
        ),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: child,
        ),
      ),
    );
  }
}

class MetaLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;

  const MetaLabel(this.text, {super.key, this.color, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GlassTypography.meta(color: color, fontSize: fontSize),
    );
  }
}

class DisplayText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  final TextAlign? textAlign;
  final FontWeight? weight;

  const DisplayText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.color,
    this.textAlign,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: GlassTypography.display(
        fontSize: fontSize,
        color: color,
        weight: weight ?? FontWeight.w800,
      ),
    );
  }
}

class GlassTabSwitcher extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final bool uppercase;

  const GlassTabSwitcher({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == selectedIndex;
          final label = uppercase ? tabs[i].toUpperCase() : tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: GlassAnimations.tabSwitch,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? context.trenzyColors.foreground
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: context.trenzyColors.foreground.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: GlassTypography.bodyFont,
                    fontSize: uppercase ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? context.trenzyColors.primaryFg
                        : context.trenzyColors.fg60,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A decorative section title with a gradient accent bar.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Color>? accentColors;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accentColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        accentColors ??
        [
          context.trenzyColors.primary,
          context.trenzyColors.primary.withValues(alpha: 0.3),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.trenzyColors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (actionLabel != null)
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: context.trenzyColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontFamily: GlassTypography.bodyFont,
                fontSize: 12,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final IconData? icon;
  final bool loading;
  final bool enabled;
  final bool isSecondary;
  final bool isAccent;
  final Color? color;
  final Color? textColor;

  const GlowButton({
    super.key,
    required this.label,
    this.onTap,
    this.width,
    this.height,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.isSecondary = false,
    this.isAccent = false,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    final bgColor =
        color ??
        (isSecondary
            ? colors.foreground.withValues(alpha: 0.08)
            : (isAccent ? null : colors.foreground));
    final fgColor =
        textColor ??
        (isSecondary
            ? colors.foreground
            : (isAccent ? colors.primaryFg : colors.background));

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: TapScale(
        onTap: enabled ? onTap : null,
        child: Container(
          width: width,
          height: height ?? 54,
          decoration: BoxDecoration(
            color: bgColor,
            gradient: isAccent ? GlassGradients.primary : null,
            borderRadius: BorderRadius.circular(GlassRadius.button),
            border: isSecondary
                ? Border.all(
                    color: colors.foreground.withValues(alpha: 0.16),
                    width: 1,
                  )
                : null,
            boxShadow: isSecondary
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                ),
              if (loading) const SizedBox(width: 10),
              if (icon != null && !loading) ...[
                Icon(icon, size: 18, color: fgColor),
                const SizedBox(width: 8),
              ],
              Text(label, style: GlassTypography.buttonLabel(color: fgColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;

  const GlassSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(GlassRadius.searchBar),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: context.trenzyColors.fg50,
            ),
            SizedBox(width: 12),
            Expanded(
              // A readOnly TextField still swallows taps to request focus,
              // which prevented the outer GestureDetector.onTap from ever
              // firing (tapping the bar did nothing). IgnorePointer lets the
              // tap pass through to the navigation handler.
              child: IgnorePointer(
                ignoring: readOnly,
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  onChanged: onChanged,
                  style: GlassTypography.body(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: GlassTypography.body(
                      color: context.trenzyColors.fg50,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class GlassTag extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool selected;

  const GlassTag({
    super.key,
    String? text,
    String? label,
    this.onTap,
    this.selected = false,
  }) : text = text ?? label ?? '';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GlassAnimations.everyday,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.trenzyColors.primary.withValues(alpha: 0.20)
              : context.trenzyColors.surfaceContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? context.trenzyColors.primary
                : context.trenzyColors.fg20,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: GlassTypography.body(
            fontSize: 12,
            color: selected
                ? context.trenzyColors.primary
                : context.trenzyColors.fg80,
          ),
        ),
      ),
    );
  }
}

class GlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: GlassAnimations.toggle,
        curve: Curves.easeOutCubic,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? context.trenzyColors.primary
              : context.trenzyColors.fg15,
          boxShadow: value
              ? [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: GlassAnimations.toggle,
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? context.trenzyColors.primaryFg
                  : context.trenzyColors.fg70,
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const GlassBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap ?? () => GoRouter.of(context).pop(),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
      ),
    );
  }
}

class PulseGlow extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final double minScale;
  final double maxScale;
  final Duration duration;

  const PulseGlow({
    super.key,
    required this.child,
    this.minOpacity = 0.6,
    this.maxOpacity = 1.0,
    this.minScale = 1.0,
    this.maxScale = 1.04,
    this.duration = const Duration(milliseconds: 2400),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

class StaggeredEntry extends StatefulWidget {
  final int index;
  final Widget child;
  final double slideOffset;
  final Duration duration;
  final double delayFactor;

  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
    this.slideOffset = 16,
    this.duration = const Duration(milliseconds: 350),
    this.delayFactor = 35,
  });

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(
      Duration(milliseconds: (widget.index * widget.delayFactor).round()),
      () {
        if (mounted) _controller.forward();
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
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlassAnimations.press,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnim.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

class LikeBounce extends StatefulWidget {
  final Widget child;
  final bool isLiked;
  final VoidCallback? onTap;

  const LikeBounce({
    super.key,
    required this.child,
    required this.isLiked,
    this.onTap,
  });

  @override
  State<LikeBounce> createState() => _LikeBounceState();
}

class _LikeBounceState extends State<LikeBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _bounce = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _controller.forward(from: 0.0);
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + _bounce.value * 0.3,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class SaveSlide extends StatefulWidget {
  final Widget child;
  final bool isSaved;
  final VoidCallback? onTap;

  const SaveSlide({
    super.key,
    required this.child,
    required this.isSaved,
    this.onTap,
  });

  @override
  State<SaveSlide> createState() => _SaveSlideState();
}

class _SaveSlideState extends State<SaveSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -0.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _controller.forward(from: 0.0).then((_) => _controller.reverse());
        widget.onTap?.call();
      },
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class FlyToCart extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final GlobalKey? cartKey;

  const FlyToCart({super.key, required this.child, this.onTap, this.cartKey});

  @override
  State<FlyToCart> createState() => _FlyToCartState();
}

class _FlyToCartState extends State<FlyToCart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _fly;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
    _fly = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _controller.forward(from: 0.0);
        widget.onTap?.call();
      },
      child: SlideTransition(
        position: _fly,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// A beautiful in-app toast notification.
class GlassToast {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final Duration duration;

  const GlassToast({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.backgroundColor,
    this.iconColor,
    this.duration = const Duration(seconds: 3),
  });

  /// Show a success toast.
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    _show(
      context,
      GlassToast(
        message: message,
        icon: Icons.check_circle_rounded,
        backgroundColor: Color(0xFF163020),
        iconColor: context.trenzyColors.emerald,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? Duration(seconds: 3),
      ),
    );
  }

  /// Show an error toast.
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    _show(
      context,
      GlassToast(
        message: message,
        icon: Icons.error_rounded,
        backgroundColor: Color(0xFF34171B),
        iconColor: context.trenzyColors.crimson,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? Duration(seconds: 4),
      ),
    );
  }

  /// Show an info toast.
  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    _show(
      context,
      GlassToast(
        message: message,
        icon: Icons.info_rounded,
        backgroundColor: Color(0xFF1E2A3A),
        iconColor: Color(0xFF5B9BD5),
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? Duration(seconds: 3),
      ),
    );
  }

  static OverlayEntry? _currentEntry;

  static void _show(BuildContext context, GlassToast toast) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (context) => _GlassToastOverlay(toast: toast),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  /// Dismiss the current toast if visible.
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _GlassToastOverlay extends StatefulWidget {
  final GlassToast toast;

  const _GlassToastOverlay({required this.toast});

  @override
  State<_GlassToastOverlay> createState() => _GlassToastOverlayState();
}

class _GlassToastOverlayState extends State<_GlassToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
    Future.delayed(widget.toast.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) GlassToast.dismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    widget.toast.backgroundColor ??
                    context.trenzyColors.glassDock,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.trenzyColors.glassDockBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.toast.icon != null) ...[
                    Icon(
                      widget.toast.icon,
                      color:
                          widget.toast.iconColor ??
                          context.trenzyColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.toast.message,
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.toast.actionLabel != null) ...[
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.toast.onAction?.call();
                        GlassToast.dismiss();
                      },
                      child: Text(
                        widget.toast.actionLabel!,
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: GlassToast.dismiss,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.trenzyColors.fg50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
