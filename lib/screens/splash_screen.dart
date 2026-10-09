import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../models/api_exception.dart';
import '../providers/user_preferences_provider.dart';
import '../services/feature_flags.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _controller;
  late final AnimationController _logoAnimationController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  Timer? _navigationTimer;
  Timer? _safetyTimer;

  bool _videoReady = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _logoAnimationController.forward();

    _controller = VideoPlayerController.asset('assets/videos/splash.mp4');

    // Global safety net: navigate regardless of video state after 6 seconds.
    _safetyTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_navigated) {
        _navigated = true;
        _navigateAfterSplash();
      }
    });

    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      if (kDebugMode) debugPrint("Loading splash video...");

      await _controller.initialize();

      if (kDebugMode) debugPrint("Video initialized!");

      if (!mounted) return;

      if (!_controller.value.isInitialized) {
        throw Exception(
          'Video failed to initialize (not supported or load error).',
        );
      }

      // Required for autoplay on web
      await _controller.setVolume(0);

      final videoDuration = _controller.value.duration;

      if (videoDuration > Duration.zero) {
        _navigationTimer = Timer(
          videoDuration + const Duration(milliseconds: 500),
          () {
            if (mounted && !_navigated) {
              if (kDebugMode) {
                debugPrint("⏰ Backup timer triggered - navigating.");
              }
              _navigated = true;
              _navigateAfterSplash();
            }
          },
        );
      } else {
        _navigationTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && !_navigated) {
            if (kDebugMode) {
              debugPrint("⏰ Fallback timer (5s) triggered - navigating.");
            }
            _navigated = true;
            _navigateAfterSplash();
          }
        });
      }

      _controller
        ..setLooping(false)
        ..play()
        ..addListener(_videoListener);

      if (mounted) {
        setState(() {
          _videoReady = true;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Video error: $e");

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_navigated) {
          _navigated = true;
          _navigateAfterSplash();
        }
      });
    }
  }

  void _navigateAfterSplash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified && !FeatureFlags.devAuthBypass) {
      if (!mounted) return;
      context.go(AppRoutes.verifyEmail);
      return;
    }

    if (user == null && !FeatureFlags.devAuthBypass) {
      if (!mounted) return;
      context.go(AppRoutes.welcome);
      return;
    }

    // Check if user has completed onboarding by looking for saved
    // preferences. Goes through the shared serverPreferencesProvider so
    // this check and the auth hydration listener issue a single request.
    try {
      // Add 3 second timeout to prevent app from freezing if API hangs
      final prefs = await ref.read(serverPreferencesProvider.future).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (!mounted) return;

      final hasPreferences =
          prefs != null &&
          prefs.isNotEmpty &&
          ((prefs['preferred_styles'] as List?)?.isNotEmpty == true ||
              (prefs['preferred_categories'] as List?)?.isNotEmpty == true ||
              (prefs['shopping_priorities'] as List?)?.isNotEmpty == true);
      context.go(hasPreferences ? AppRoutes.home : AppRoutes.onboarding);
    } on ApiException catch (e) {
      if (!mounted) return;
      // If we get a 401 (invalid/expired token), sign out and send to welcome screen
      if (e.statusCode == 401) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.go(AppRoutes.welcome);
        }
      } else {
        // For other API errors, send to onboarding so they can set preferences
        context.go(AppRoutes.onboarding);
      }
    } catch (_) {
      if (!mounted) return;
      // On network error or timeout, default to home
      context.go(AppRoutes.home);
    }
  }

  void _videoListener() {
    if (_navigated) return;

    final value = _controller.value;

    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _navigated = true;
      _navigationTimer?.cancel();
      _safetyTimer?.cancel();
      _navigateAfterSplash();
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _safetyTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Animated logo while video loads
          AnimatedBuilder(
            animation: _logoAnimationController,
            builder: (context, child) {
              return Opacity(
                opacity: _videoReady ? 0.0 : _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Image.asset(
                    'assets/logo/app_logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
              );
            },
          ),
          // Video player once ready
          if (_videoReady)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}