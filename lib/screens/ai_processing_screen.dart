import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/trenzy_colors.dart';

class AiProcessingScreen extends StatelessWidget {
  const AiProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Builder(builder: (context) => Container(
            decoration: BoxDecoration(
              color: context.trenzyColors.background,
            ),
          )),
          const _GrainOverlay(),
          const _AiProcessingState(),
        ],
      ),
    );
  }
}

class _StepData {
  final String label;
  final IconData icon;
  final double start;
  final double end;

  const _StepData(this.label, this.icon, this.start, this.end);
}

class _ParticleData {
  final double x;
  final double y;
  final double speed;
  final double drift;
  final double radius;
  final Color color;
  final double opacity;

  const _ParticleData({
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
    required this.radius,
    required this.color,
    required this.opacity,
  });
}

class _NetworkNode {
  final double x;
  final double y;
  final double radius;

  const _NetworkNode(this.x, this.y, this.radius);
}

class _NetworkConnection {
  final int a;
  final int b;
  final double phase;

  const _NetworkConnection(this.a, this.b, this.phase);
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_ParticleData> particles;

  _ParticlePainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = (p.x * size.width + progress * p.drift * size.width) % size.width;
      final y = (p.y * size.height - progress * p.speed * size.height) % size.height;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _NetworkPainter extends CustomPainter {
  final double progress;
  final List<_NetworkNode> nodes;
  final List<_NetworkConnection> connections;

  _NetworkPainter({
    required this.progress,
    required this.nodes,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final conn in connections) {
      if (conn.a >= nodes.length || conn.b >= nodes.length) continue;
      final a = nodes[conn.a];
      final b = nodes[conn.b];
      final ax = a.x * size.width;
      final ay = a.y * size.height;
      final bx = b.x * size.width;
      final by = b.y * size.height;

      final opacity = 0.15 + 0.15 * sin(progress * 2 * pi + conn.phase * 2 * pi);
      linePaint.color = const Color(0xFFD79D8A).withValues(alpha: opacity); // rose-gold
      canvas.drawLine(Offset(ax, ay), Offset(bx, by), linePaint);

      final dotProgress = (progress + conn.phase) % 1.0;
      final dx = bx - ax;
      final dy = by - ay;
      final dotX = ax + dx * dotProgress;
      final dotY = ay + dy * dotProgress;
      final dotPaint = Paint()
        ..color = const Color(0xFFD79D8A).withValues(alpha: 0.6); // rose-gold
      canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFFD79D8A).withValues(alpha: 0.2) // rose-gold
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
    }

    for (final node in nodes) {
      final nx = node.x * size.width;
      final ny = node.y * size.height;
      final pulse = 0.8 + 0.2 * sin(progress * 2 * pi + node.x + node.y);
      final nodePaint = Paint()
        ..color = const Color(0xFFD79D8A).withValues(alpha: 0.25 * pulse); // rose-gold
      canvas.drawCircle(Offset(nx, ny), node.radius * pulse, nodePaint);

      final innerPaint = Paint()
        ..color = const Color(0xFFD79D8A).withValues(alpha: 0.4 * pulse); // rose-gold
      canvas.drawCircle(Offset(nx, ny), node.radius * 0.4 * pulse, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AiProcessingState extends StatefulWidget {
  const _AiProcessingState();

  @override
  State<_AiProcessingState> createState() => _AiProcessingStateState();
}

class _AiProcessingStateState extends State<_AiProcessingState>
    with TickerProviderStateMixin {
  static const _steps = [
    _StepData('Analyzing preferences...', Icons.analytics_outlined, 0.0, 0.25),
    _StepData('Mapping your aesthetic...', Icons.palette_outlined, 0.25, 0.5),
    _StepData('Finding your style tribe...', Icons.diversity_3_outlined, 0.5, 0.75),
    _StepData('Crafting your persona...', Icons.auto_fix_high_outlined, 0.75, 1.0),
  ];

  late final AnimationController _progressCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _networkCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _iconPulseCtrl;

  late final Animation<double> _progressAnim;
  late final Animation<double> _stepFade;
  late final Animation<double> _leftCardAnim;
  late final Animation<double> _rightCardAnim;

  int _currentStep = 0;
  bool _isComplete = false;

  final List<_ParticleData> _particles = [];
  final List<_NetworkNode> _nodes = [];
  final List<_NetworkConnection> _connections = [];

  @override
  void initState() {
    super.initState();
    _initParticles();
    _initNetwork();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _networkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _iconPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOutCubic,
    );

    _stepFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _leftCardAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _rightCardAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scheduleSteps();
  }

  void _initParticles() {
    final rng = Random(42);
    for (int i = 0; i < 35; i++) {
      final isForeground = i < 15;
      _particles.add(_ParticleData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.015 + rng.nextDouble() * 0.025,
        drift: (rng.nextDouble() - 0.5) * 0.015,
        radius: isForeground ? 2.5 + rng.nextDouble() * 1.5 : 1.0 + rng.nextDouble() * 1.0,
        color: rng.nextBool() ? const Color(0xFFD79D8A) : const Color(0xFFA89F95), // rose-gold / cashmere
        opacity: isForeground ? 0.4 + rng.nextDouble() * 0.3 : 0.1 + rng.nextDouble() * 0.15,
      ));
    }
  }

  void _initNetwork() {
    final rng = Random(123);
    for (int i = 0; i < 9; i++) {
      _nodes.add(_NetworkNode(
        rng.nextDouble(),
        rng.nextDouble(),
        6.0 + rng.nextDouble() * 6.0,
      ));
    }
    final connectionSet = <String>{};
    for (int i = 0; i < _nodes.length; i++) {
      for (int j = i + 1; j < _nodes.length; j++) {
        final dx = _nodes[i].x - _nodes[j].x;
        final dy = _nodes[i].y - _nodes[j].y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 0.6 && connectionSet.length < 12) {
          final key = '$i-$j';
          if (!connectionSet.contains(key)) {
            connectionSet.add(key);
            _connections.add(_NetworkConnection(i, j, rng.nextDouble()));
          }
        }
      }
    }
    if (_connections.isEmpty && _nodes.length >= 2) {
      for (int i = 0; i < min(8, _nodes.length - 1); i++) {
        _connections.add(_NetworkConnection(i, i + 1, rng.nextDouble()));
      }
    }
  }

  Future<void> _scheduleSteps() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _cardCtrl.forward();
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _currentStep = i);
      _progressCtrl.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _isComplete = true);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    _networkCtrl.dispose();
    _glowCtrl.dispose();
    _cardCtrl.dispose();
    _iconPulseCtrl.dispose();
    super.dispose();
  }

  double get _currentProgress {
    if (_currentStep >= _steps.length) return 1.0;
    final step = _steps[_currentStep];
    return step.start + (step.end - step.start) * _progressAnim.value;
  }

  String get _currentLabel {
    if (_isComplete) return 'Complete!';
    return _steps[_currentStep.clamp(0, _steps.length - 1)].label;
  }

  IconData get _currentIcon {
    if (_isComplete) return Icons.check_circle_outline;
    return _steps[_currentStep.clamp(0, _steps.length - 1)].icon;
  }

  void _onContinue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Persona Ready!'),
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 2),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _ParticlePainter(
                  progress: _particleCtrl.value,
                  particles: _particles,
                ),
              );
            },
          ),
        ),
        SizedBox.expand(
          child: AnimatedBuilder(
            animation: _networkCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _NetworkPainter(
                  progress: _networkCtrl.value,
                  nodes: _nodes,
                  connections: _connections,
                ),
              );
            },
          ),
        ),
        _buildAmbientGlow(),
        _buildHeader(),
        _buildMainContent(),
        _buildBottomNavBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: context.trenzyColors.background.withValues(alpha: 0.4),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.2)),
            ),
            child: CircleAvatar(
              backgroundColor: context.trenzyColors.graphite,
              child: Text('U', style: TextStyle(color: context.trenzyColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        title: Text(
          'Trenzy',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 36,
            color: context.trenzyColors.primary,
          ),
        ),
        actions: [
            IconButton(
              icon: Icon(Icons.notifications, color: context.trenzyColors.primary),
              onPressed: () => context.push(AppRoutes.notifications),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProgressRing(),
          const SizedBox(height: 48),
          _buildStatusMessage(),
          const SizedBox(height: 32),
          _buildDetailCards(),
          if (_isComplete) ...[
            const SizedBox(height: 32),
            _buildContinueButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 288,
      height: 288,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 288,
            height: 288,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD79D8A).withValues(alpha: 0.05)),
            ),
          ),
          Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD79D8A).withValues(alpha: 0.05),
            ),
          ),
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (context, _) {
              return SizedBox(
                width: 256,
                height: 256,
                child: CircularProgressIndicator(
                  value: _currentProgress,
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD79D8A)),
                  backgroundColor: const Color(0xFF251F1D),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _progressCtrl,
            builder: (context, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_currentProgress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 48,
                      color: Color(0xFFD79D8A), // rose-gold accent
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _stepFade,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _isComplete ? 1.0 : _stepFade.value,
                        child: Text(
                          _isComplete ? 'Ready' : 'Synthesizing',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFA89F95), // cashmere taupe
                            letterSpacing: 0.3,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _stepFade,
          builder: (context, _) {
            return Column(
              children: [
                Icon(
                  _currentIcon,
                  color: const Color(0xFFD79D8A), // rose-gold accent
                  size: 28,
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: _isComplete ? 1.0 : _stepFade.value,
                  child: Text(
                    _currentLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFFAF6F0), // alabaster warm white
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _leftCardAnim,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _leftCardAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _leftCardAnim.value)),
                        child: _buildGlassCard(
                          'Logic', 'Vector Mapping', Icons.model_training,
                          _leftCardAnim,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: _rightCardAnim,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _rightCardAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _rightCardAnim.value)),
                        child: _buildGlassCard(
                          'Vision', 'Aesthetic Engine', Icons.auto_awesome,
                          _rightCardAnim,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFullWidthGlassCard(),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
      String title, String subtitle, IconData icon, Animation<double> anim) {
    return AnimatedBuilder(
      animation: _iconPulseCtrl,
      builder: (context, _) {
        final shimmerAngle = _iconPulseCtrl.value * 0.1 - 0.05;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1715).withValues(alpha: 0.4), // warm obsidian
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD79D8A)
                  .withValues(alpha: 0.08 + 0.04 * _iconPulseCtrl.value),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.rotate(
                angle: shimmerAngle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD79D8A).withValues(alpha: 0.1), // rose-gold tint
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFFD79D8A), size: 20), // rose-gold
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: const Color(0xFFA89F95).withValues(alpha: 0.6), // cashmere
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFAF6F0), // alabaster
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullWidthGlassCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1715).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFAF6F0).withValues(alpha: 0.1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checkroom, color: Color(0xFFD79D8A), size: 20), // rose-gold
          SizedBox(width: 12),
          Text(
            'Processing 3,400+ Silhouette Matrices',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA89F95), // cashmere
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return AnimatedBuilder(
      animation: _cardCtrl,
      builder: (context, _) {
        return FadeTransition(
          opacity: _cardCtrl,
          child: SizedBox(
            height: 52,
            width: 220,
            child: ElevatedButton(
              onPressed: _onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD79D8A), // rose-gold CTA
                foregroundColor: const Color(0xFF120F0E), // espresso noir
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        decoration: BoxDecoration(
          color: context.trenzyColors.background.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border(
              top: BorderSide(
                  color: context.trenzyColors.foreground.withValues(alpha: 0.05))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(icon: Icons.home, label: 'Home', isSelected: true),
            _BottomNavItem(icon: Icons.search, label: 'Discover'),
            _BottomNavItem(icon: Icons.style, label: 'Social'),
            _BottomNavItem(icon: Icons.checkroom, label: 'Wardrobe'),
            _BottomNavItem(icon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) {
        final glowScale =
            1.0 + 0.12 * sin(_glowCtrl.value * 2 * pi);
        final glowOffset =
            0.05 * sin(_glowCtrl.value * 2 * pi + 1.0);
        return Stack(
          children: [
            Positioned(
              top: -100 + glowOffset * 50,
              left: -100 - glowOffset * 30,
              child: Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD79D8A).withValues(alpha: 0.05), // rose-gold glow
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50 - glowOffset * 40,
              right: -50 + glowOffset * 20,
              child: Transform.scale(
                scale: 1.0 + 0.1 * sin(_glowCtrl.value * 2 * pi + 2.0),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA89F95).withValues(alpha: 0.08), // cashmere soft glow
                  ),
                ),
              ),
            ),
            Positioned(
              top: 200 + glowOffset * 30,
              right: -80,
              child: Transform.scale(
                scale: 0.8 + 0.15 * sin(_glowCtrl.value * 2 * pi + 3.0),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD79D8A).withValues(alpha: 0.04), // rose-gold tertiary glow
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.03,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
                'https://www.transparenttextures.com/patterns/p6-dark.png'),
            repeat: ImageRepeat.repeat,
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected
              ? const Color(0xFFD79D8A) // rose-gold
              : const Color(0xFFC6C6C6).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: isSelected
                ? const Color(0xFFD79D8A) // rose-gold
                : const Color(0xFFC6C6C6).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
