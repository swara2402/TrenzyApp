import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/utils/firebase_error_handler.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
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
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: context.trenzyColors.foreground, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Password reset link sent to ${_emailController.text}',
                  style: GlassTypography.body(color: context.trenzyColors.foreground, fontSize: 14),
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

      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      final message = friendlyFirebaseError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: context.trenzyColors.foreground, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GlassTypography.body(color: context.trenzyColors.foreground, fontSize: 14),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        title: Text(
          'Trenzy',
          style: GlassTypography.display(fontSize: 20, color: context.trenzyColors.primary),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Decorative aura ─────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0x2CF2CA50),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.trenzyColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset,
                          size: 38,
                          color: context.trenzyColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 28),

                  // ── Title ───────────────────────────────────────────
                  DisplayText(
                    'Forgot Password?',
                    fontSize: 28,
                    weight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),

                  // ── Description ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Enter your email address and we\'ll send you a secure link to reset your password.',
                      textAlign: TextAlign.center,
                      style: GlassTypography.body(
                        fontSize: 15,
                        color: context.trenzyColors.fg50,
                      ),
                    ),
                  ),
                  SizedBox(height: 40),

                  // ── Glass card form ─────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(GlassRadius.panel),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.fg08,
                          borderRadius: BorderRadius.circular(GlassRadius.panel),
                          border: Border.all(color: context.trenzyColors.glassBorder),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              style: GlassTypography.body(color: context.trenzyColors.foreground),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: GlassTypography.body(color: context.trenzyColors.mutedFg),
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                  color: context.trenzyColors.mutedFg,
                                ),
                                filled: true,
                                fillColor: context.trenzyColors.graphite,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GlassRadius.input),
                                  borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GlassRadius.input),
                                  borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GlassRadius.input),
                                  borderSide: BorderSide(color: context.trenzyColors.primary),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GlassRadius.input),
                                  borderSide: BorderSide(color: context.trenzyColors.crimson.withValues(alpha: 0.6)),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GlassRadius.input),
                                  borderSide: BorderSide(color: context.trenzyColors.crimson),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            GlowButton(
                              label: 'Send Reset Link',
                              onTap: _isLoading ? null : _sendResetLink,
                              loading: _isLoading,
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // ── Back to login ───────────────────────────────────
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: context.trenzyColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back to Login',
                          style: GlassTypography.body(
                            fontSize: 14,
                            color: context.trenzyColors.primary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
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
