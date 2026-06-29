// lib/screens/splash_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../widgets/trenzy_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double _ribbonProgress = 0.0;
  double _logoScale = 0.0;
  double _logoOpacity = 0.0;
  double _pulseScale = 0.0;
  double _pulseOpacity = 0.0;
  double _textOpacity = 0.0;
  double _sloganOpacity = 0.0;
  double _rotation = 0.0;

  double _clamp01(double value) => value.clamp(0.0, 1.0);

  Timer? _timer;
  int _elapsedMs = 0;

  // Particle system
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Initialize particles
    for (int i = 0; i < 50; i++) {
      _particles.add(
        Particle(
          x: Random().nextDouble(),
          y: Random().nextDouble(),
          size: Random().nextDouble() * 3 + 1,
          speed: Random().nextDouble() * 0.5 + 0.1,
          opacity: Random().nextDouble() * 0.5 + 0.1,
        ),
      );
    }

    // Animation controller for 60fps
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addListener(() {
            setState(() {
              _elapsedMs += 16;
              _updateAnimation(_controller.value);
            });
          });

    _controller.forward();

    // Navigation timer
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go(AppRoutes.login);
      }
    });
  }

  void _updateAnimation(double progress) {
    // Scene 1: Darkness (0-0.8s)
    if (progress < 0.27) {
      _ribbonProgress = 0;
      _logoScale = 0;
      _logoOpacity = 0;
      _pulseScale = 0;
      _pulseOpacity = 0;
      _textOpacity = 0;
      _sloganOpacity = 0;
    }
    // Scene 2: Ribbons (0.8-1.7s)
    else if (progress < 0.57) {
      _ribbonProgress = (progress - 0.27) / 0.3;
      _logoScale = 0;
      _logoOpacity = 0;
      _pulseScale = 0;
      _pulseOpacity = 0;
      _textOpacity = 0;
      _sloganOpacity = 0;
      _rotation = _ribbonProgress * 2 * pi;
    }
    // Scene 3: The Magic Click (1.7-2.3s)
    else if (progress < 0.77) {
      _ribbonProgress = 1.0;
      final snapProgress = (progress - 0.57) / 0.2;
      _logoScale = min(1.0, snapProgress * 2);
      _logoOpacity = min(1.0, snapProgress * 3);
      _pulseScale = snapProgress;
      _pulseOpacity = snapProgress < 0.5
          ? snapProgress * 2
          : (1 - snapProgress) * 2;
      _rotation = 4 * pi;

      // Golden pulse
      if (snapProgress > 0.3) {
        _pulseScale = (snapProgress - 0.3) * 3;
        _pulseOpacity = max(0, 1 - (snapProgress - 0.3) * 3);
      }
    }
    // Scene 4: Brand Reveal (2.3-3s)
    else {
      _logoScale = 1.0;
      _logoOpacity = 1.0;
      _pulseOpacity = 0;

      final textProgress = (progress - 0.77) / 0.1;
      _textOpacity = min(1.0, textProgress * 2);

      final sloganProgress = (progress - 0.87) / 0.1;
      _sloganOpacity = min(1.0, sloganProgress * 3);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(color: Colors.black),

          // Particles
          ..._particles.map((particle) {
            return Positioned(
              left: particle.x * screenSize.width,
              top:
                  (particle.y + sin(_elapsedMs * particle.speed * 0.001)) *
                      (screenSize.height / 2) +
                  centerY -
                  100,
              child: Container(
                width: particle.size,
                height: particle.size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: particle.opacity * 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),

          // Brown Ribbon (Left)
          if (_ribbonProgress > 0)
            Positioned(
              left: -50 + _ribbonProgress * 100,
              top: centerY - 100,
              child: Transform.rotate(
                angle: _rotation * 0.5,
                child: Container(
                  width: 80,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA67B5B), Color(0xFF6B4226)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),

          // Gold Ribbon (Right)
          if (_ribbonProgress > 0)
            Positioned(
              right: -50 + _ribbonProgress * 100,
              top: centerY - 100,
              child: Transform.rotate(
                angle: -_rotation * 0.5,
                child: Container(
                  width: 80,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4D03F), Color(0xFFC9A227)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),

          // Logo Group
          Center(
            child: Transform.scale(
              scale: _logoScale,
              child: Opacity(
                opacity: _clamp01(_logoOpacity),
                child: TrenzyLogo(size: 120, wordmark: false, glow: true),
              ),
            ),
          ),

          // Golden Pulse
          Center(
            child: Transform.scale(
              scale: _pulseScale * 3,
              child: Opacity(
                opacity: _clamp01(_pulseOpacity),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        const Color(0xFFD4AF37).withValues(alpha: 0),
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Hexagons
          if (_logoOpacity > 0)
            Positioned(
              top: centerY - 110,
              left: centerX - 15,
              child: Opacity(
                opacity: _clamp01(_logoOpacity),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    shape: const PolygonBorder(sides: 6),
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ),
            ),

          if (_logoOpacity > 0)
            Positioned(
              bottom: centerY - 110,
              left: centerX - 15,
              child: Opacity(
                opacity: _clamp01(_logoOpacity),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    shape: const PolygonBorder(sides: 6),
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ),
            ),

          // TRENZY Text
          Positioned(
            left: 0,
            right: 0,
            top: centerY + 80,
            child: Opacity(
              opacity: _clamp01(_textOpacity),
              child: const Text(
                'TRENZY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // Slogan Text
          Positioned(
            left: 0,
            right: 0,
            top: centerY + 130,
            child: Opacity(
              opacity: _clamp01(_sloganOpacity),
              child: const Text(
                'Shopping Made Social',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFD4AF37),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Particle class
class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Hexagon shape
class PolygonBorder extends ShapeBorder {
  final int sides;
  final double borderRadius;

  const PolygonBorder({required this.sides, this.borderRadius = 0});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final center = rect.center;
    final radius = rect.width / 2;
    final angle = (2 * pi / sides);

    for (int i = 0; i < sides; i++) {
      final x = center.dx + radius * cos(i * angle - pi / 2);
      final y = center.dy + radius * sin(i * angle - pi / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) {
    return PolygonBorder(sides: sides, borderRadius: borderRadius * t);
  }
}
