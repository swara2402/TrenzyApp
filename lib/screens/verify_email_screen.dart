import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/utils/firebase_error_handler.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _isResending = false;
  bool _isChecking = false;
  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: GlassAnimations.signature,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _entryController.forward();
    _pollEmailVerification();
  }

  void _pollEmailVerification() {
    _timer = Timer.periodic(Duration(seconds: 5), (_) async {
      bool verified = false;
      try {
        verified = await ref
            .read(authProvider.notifier)
            .checkEmailVerification();
      } catch (_) {
        // Transient check failures are retried on the next tick; the
        // explicit "I've verified" button surfaces errors to the user.
        return;
      }
      if (verified && mounted) {
        _timer?.cancel();
        _redirectAfterVerification();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  /// Checks whether the user has completed onboarding (has saved preferences)
  /// and redirects accordingly. Matches the logic in [SplashScreen].
  Future<void> _redirectAfterVerification() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      context.go(AppRoutes.welcome);
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final prefs = await api.getPreferences();
      final prefData = prefs['preferences'] as Map<String, dynamic>?;
      final hasPreferences =
          prefs.isNotEmpty &&
          ((prefData?['preferred_styles'] as List?)?.isNotEmpty == true ||
              (prefData?['preferred_categories'] as List?)?.isNotEmpty ==
                  true ||
              (prefData?['shopping_priorities'] as List?)?.isNotEmpty == true);

      if (!mounted) return;
      if (hasPreferences) {
        context.go(AppRoutes.home);
      } else {
        // Start onboarding preference flow from Step 1, mark source for back-navigation
        context.go('${AppRoutes.favoriteCategories}?source=signup');
      }
    } catch (_) {
      if (!mounted) return;
      // If we can't fetch preferences, still start the onboarding flow to be safe
      context.go('${AppRoutes.favoriteCategories}?source=signup');
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authProvider.notifier).resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: context.trenzyColors.foreground,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Verification email sent!',
                style: GlassTypography.body(
                  color: context.trenzyColors.foreground,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: context.trenzyColors.emerald,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.card),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = friendlyFirebaseError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: context.trenzyColors.foreground,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GlassTypography.body(
                    color: context.trenzyColors.foreground,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: context.trenzyColors.crimson,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.card),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleCheckVerification() async {
    setState(() => _isChecking = true);
    bool verified;
    try {
      verified = await ref.read(authProvider.notifier).checkEmailVerification();
    } catch (e) {
      // Surface the failure instead of leaving the button spinning forever.
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: context.trenzyColors.foreground,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  friendlyFirebaseError(e),
                  style: GlassTypography.body(
                    color: context.trenzyColors.foreground,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: context.trenzyColors.crimson,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.card),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (verified) {
      _redirectAfterVerification();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: context.trenzyColors.foreground,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Email not verified yet. Please check your inbox.',
                  style: GlassTypography.body(
                    color: context.trenzyColors.foreground,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFD4A830),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.card),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Decorative aura ─────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x2CF2CA50), Colors.transparent],
                          ),
                        ),
                      ),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.trenzyColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          size: 44,
                          color: context.trenzyColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // ── Title ───────────────────────────────────────────
                  DisplayText(
                    'Verify your email',
                    fontSize: 28,
                    weight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // ── Instructions ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'We\'ve sent a verification email to',
                      style: GlassTypography.body(
                        fontSize: 16,
                        color: context.trenzyColors.mutedFg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    email,
                    style: GlassTypography.body(
                      fontSize: 16,
                      weight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Click the link in the email to verify your account, then come back here.',
                      style: GlassTypography.body(
                        fontSize: 14,
                        color: context.trenzyColors.fg50,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 40),

                  // ── Glass card with buttons ─────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(GlassRadius.panel),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.fg08,
                          borderRadius: BorderRadius.circular(
                            GlassRadius.panel,
                          ),
                          border: Border.all(
                            color: context.trenzyColors.glassBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Primary action: Check verification
                            GlowButton(
                              label: "I've verified — Continue",
                              onTap: _isChecking
                                  ? null
                                  : _handleCheckVerification,
                              loading: _isChecking,
                              width: double.infinity,
                            ),
                            SizedBox(height: 16),

                            // Secondary action: Resend email
                            SizedBox(
                              width: double.infinity,
                              child: TapScale(
                                onTap: _isResending ? null : _handleResend,
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      GlassRadius.button,
                                    ),
                                    border: Border.all(
                                      color: context.trenzyColors.primary
                                          .withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isResending
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: context.trenzyColors.primary,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.refresh,
                                              size: 20,
                                              color:
                                                  context.trenzyColors.primary,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'RESEND VERIFICATION EMAIL',
                                              style:
                                                  GlassTypography.buttonLabel(
                                                    color: context
                                                        .trenzyColors
                                                        .primary,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // ── Logout link ─────────────────────────────────────
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Text(
                      'Use a different email',
                      style: GlassTypography.body(
                        fontSize: 14,
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
