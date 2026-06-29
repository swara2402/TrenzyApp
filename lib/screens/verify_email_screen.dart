import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../widgets/app_widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldown = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown > 0) {
        setState(() {
          _cooldown--;
        });
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      // Rely on Firebase's own emailVerified flag.
      // The client may take a moment to propagate the verification state,
      // so we retry a few times.
      const maxAttempts = 5;
      const attemptDelay = Duration(seconds: 1);

      bool verified = false;

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
        if (firebaseUser == null) break;

        await firebaseUser.reload();

        // Note: reload() updates the cached user fields on the client.
        if (firebaseUser.emailVerified) {
          verified = true;
          break;
        }

        if (attempt < maxAttempts) {
          await Future.delayed(attemptDelay);
        }
      }

      if (verified) {
        setState(() {
          _isSuccess = true;
          _message = 'Email successfully verified!';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go(AppRoutes.home);
          }
        });
      } else {
        setState(() {
          _message =
              'Verification link not clicked yet. Please check your inbox.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error checking verification status: ${e.toString()}';
      });
    } finally {
      setState(() {
        _checking = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    if (_resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
      if (firebaseUser != null) {
        await firebaseUser.sendEmailVerification();
        _startCooldown();
        setState(() {
          _message = 'Verification email resent successfully.';
        });
      } else {
        setState(() {
          _message = 'User session not found. Please log in again.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to resend email: ${e.toString()}';
      });
    } finally {
      setState(() {
        _resending = false;
      });
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = ref.watch(firebaseAuthProvider).currentUser;
    final email = firebaseUser?.email ?? 'your email';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(onToggleTheme: widget.onToggleTheme),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: isDark ? 0.22 : 0.16),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verify Your Email',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We have sent a verification link to:\n',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your inbox and click the verification link to proceed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    if (_message != null) ...[
                      if (_isSuccess)
                        SuccessPulseBanner(
                          title: 'Verification Complete',
                          message: _message!,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: panelDecoration(context, radius: 18)
                              .copyWith(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.error.withValues(alpha: 0.4),
                                ),
                              ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TapScale(
                        child: FilledButton.icon(
                          onPressed: _checking ? null : _checkStatus,
                          icon: _checking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _checking ? 'Checking...' : 'I have verified',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TapScale(
                        child: OutlinedButton.icon(
                          onPressed: (_resending || _cooldown > 0)
                              ? null
                              : _resendEmail,
                          icon: _resending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _cooldown > 0
                                ? 'Resend in ${_cooldown}s'
                                : 'Resend Verification Email',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Use a different account / Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
