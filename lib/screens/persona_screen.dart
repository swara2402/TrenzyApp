import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/providers/user_preferences_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/models/wardrobe_model.dart';

// ─── Confetti Particle Engine ─────────────────────────────────────────────

/// A single confetti particle with its own random trajectory.
class _ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double fallSpeed;
  final double drift;
  final double startDelay;

  _ConfettiParticle._({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.fallSpeed,
    required this.drift,
    required this.startDelay,
  });

  factory _ConfettiParticle.random(Random rng, Size size) {
    const palette = [
      Color(0xFFF2CA50),  // gold/primary
      Color(0xFF2ECC71),  // green
      Color(0xFF9B59B6),  // purple
      Color(0xFFE74C3C),  // red
      Color(0xFF3498DB),  // blue
      Color(0xFF1ABC9C),  // teal
      Color(0xFFE91E63),  // pink
      Color(0xFFFF8800),  // orange
      Color(0xFFFFFFFF),  // white
    ];

    return _ConfettiParticle._(
      // Spread particles across the full width
      x: rng.nextDouble() * size.width,
      // Start above the screen so they fall in
      y: -20 - rng.nextDouble() * size.height * 0.6,
      color: palette[rng.nextInt(palette.length)],
      size: 6.0 + rng.nextDouble() * 6.0,
      rotation: rng.nextDouble() * 2 * pi,
      rotationSpeed: (rng.nextDouble() - 0.5) * 0.1,
      fallSpeed: 1.5 + rng.nextDouble() * 2.5,
      drift: (rng.nextDouble() - 0.5) * 1.5,
      startDelay: rng.nextDouble() * 0.6,
    );
  }
}

/// Renders falling confetti particles using [CustomPainter].
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress; // 0.0 – 1.0

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Skip particles that haven't started yet
      final localProgress = (progress - p.startDelay).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      // Fall distance
      final fallDistance = localProgress * p.fallSpeed * 120;
      final y = p.y + fallDistance;

      // If it's fallen past the screen, skip
      if (y > size.height + 20) continue;

      // Horizontal drift with a gentle sine wave
      final driftX = sin(localProgress * pi * 2) * 15 * p.drift;
      final x = p.x + driftX;

      // Rotation
      final rotation = p.rotation + localProgress * p.rotationSpeed * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // Draw as small rounded rectangles (confetti pieces)
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size * 0.6,
        height: p.size,
      );

      final paint = Paint()
        ..color = p.color.withValues(alpha: (1.0 - localProgress * 0.3).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Fades in + slides up automatically after a configurable [delay] from mount.
/// Used for the subtitle and description so they appear shortly after the name pulse.
class _DelayedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _DelayedFadeIn({
    required this.child,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<_DelayedFadeIn> createState() => _DelayedFadeInState();
}

class _DelayedFadeInState extends State<_DelayedFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that performs a subtle pulse/scale + golden glow animation once
/// when triggered. Used for the persona name text.
class _PulseText extends StatefulWidget {
  final Widget child;
  final Color? glowColor;

  const _PulseText({super.key, required this.child}) : glowColor = null;

  @override
  State<_PulseText> createState() => _PulseTextState();
}

class _PulseTextState extends State<_PulseText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);
    // Glow opacity pulses 0.0 → 0.55 → 0.0 in lockstep with the scale
    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  void trigger() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? context.trenzyColors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _glowOpacity.value;
        return Transform.scale(
          scale: _scale.value,
          child: opacity > 0.01
              ? DefaultTextStyle(
                  style: TextStyle(
                    shadows: [
                      // Outer soft glow
                      Shadow(
                        color: glowColor.withValues(alpha: opacity * 0.25),
                        blurRadius: 24,
                      ),
                      // Mid glow
                      Shadow(
                        color: glowColor.withValues(alpha: opacity * 0.4),
                        blurRadius: 14,
                      ),
                      // Inner hot glow
                      Shadow(
                        color: glowColor.withValues(alpha: opacity * 0.55),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: child!,
                )
              : child!,
        );
      },
      child: widget.child,
    );
  }
}

/// Overlays a burst of confetti particles that animates once.
class _ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const _ConfettiOverlay({super.key, required this.child});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3200),
    );
    _particles = [];
  }

  void trigger() {
    if (_hasPlayed) return;
    _hasPlayed = true;
    final rng = Random();
    final size = MediaQuery.of(context).size;
    _particles.clear();
    for (int i = 0; i < 80; i++) {
      _particles.add(_ConfettiParticle.random(rng, size));
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating && !_hasPlayed) {
              return const SizedBox.shrink();
            }
            return IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    _particles,
                    _controller.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Map<String, dynamic> _snakeCase(Map<String, dynamic> input) {
  return input.map((key, value) {
    final snake = key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
    return MapEntry(snake, value);
  });
}

class PersonaScreen extends ConsumerStatefulWidget {
  const PersonaScreen({super.key});

  @override
  ConsumerState<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends ConsumerState<PersonaScreen> {
  bool _isSaving = false;
  bool _generatedOnce = false;

  Future<void> _ensurePersona() async {
    if (_generatedOnce) return;
    final existing = ref.read(personaProvider).valueOrNull;
    if (existing != null && existing.id != 0) return;

    _generatedOnce = true;

    try {
      final api = ref.read(apiServiceProvider);
      final prefs = ref.read(userPreferencesProvider);
      await api.generatePersona(preferences: _snakeCase(prefs.toJson()));
      ref.invalidate(personaProvider);
    } catch (_) {
      // Non-blocking — user can retry via Continue button
    }
  }

  bool _hasCelebrated = false;
  final _confettiKey = GlobalKey<_ConfettiOverlayState>();
  final _pulseKey = GlobalKey<_PulseTextState>();

  Future<void> _onContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(apiServiceProvider).savePreferences(onboardingStep: 5);
      ref.read(userPreferencesProvider.notifier).completeOnboarding();
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not finish saving your onboarding: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _onContinue(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personaAsync = ref.watch(personaProvider);

    ref.listen(personaProvider, (prev, next) {
      next.whenOrNull(data: (StylePersona? data) {
        // Generate persona if needed (also when placeholder default is returned)
        if ((data == null || data.id == 0) && !_generatedOnce) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePersona());
        }
        // Celebrate once on first successful generation (null → non-null)
        if (data != null && data.id != 0 && prev?.valueOrNull == null && !_hasCelebrated) {
          _hasCelebrated = true;
          Future.delayed(Duration(milliseconds: 200), () {
            if (mounted) {
              _confettiKey.currentState?.trigger();
              _pulseKey.currentState?.trigger();
            }
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: _ConfettiOverlay(
        key: _confettiKey,
        child: personaAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: context.trenzyColors.primary),
              SizedBox(height: 24),
              Text(
                'Understanding your fashion taste...',
                style: TextStyle(
                  fontSize: 18,
                  color: context.trenzyColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Could not determine your style persona yet.',
                  style: TextStyle(
                    fontSize: 18,
                    color: context.trenzyColors.mutedFg,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.trenzyColors.primary,
                    foregroundColor: context.trenzyColors.primaryFg,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Continue to Home'),
                ),
              ],
            ),
          ),
        ),
        data: (StylePersona? persona) {
          if (persona == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Creating your style persona...',
                      style: TextStyle(
                        fontSize: 18,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(
                      color: context.trenzyColors.primary,
                    ),
                    SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.trenzyColors.primary,
                        foregroundColor: context.trenzyColors.primaryFg,
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Continue to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DelayedFadeIn(
                    delay: Duration(milliseconds: 400),
                    child: Text(
                      'Your AI Style Persona is',
                      style: TextStyle(
                        fontSize: 22,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _PulseText(
                    key: _pulseKey,
                    child: Text(
                      persona.name,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  _DelayedFadeIn(
                    delay: Duration(milliseconds: 550),
                    child: Text(
                      persona.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                  ),
                  SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.trenzyColors.primary,
                      foregroundColor: context.trenzyColors.primaryFg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Continue to Home'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  }
}