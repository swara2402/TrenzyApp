import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/auth_provider.dart';
import '../providers/analytics_service_provider.dart';
import '../router/app_router.dart';
import '../utils/error_utils.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_widgets.dart';
import '../services/google_sign_in_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.onToggleTheme, this.initialMode});

  final VoidCallback onToggleTheme;
  final String? initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late bool _isLogin;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    // 'signup' mode means we open the sign-up form, otherwise login.
    _isLogin = widget.initialMode != 'signup';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (_isLogin) {
      await ref.read(authProvider.notifier).login(email, password);
    } else {
      await ref.read(authProvider.notifier).signup(name, email, password);
    }

    if (!mounted) return;

    final latestAuthState = ref.read(authProvider);
    if (latestAuthState.value != null) {
      // SUCCESS — fire login OR signup analytics event (split for clarity).
      // (Previously the code fired 'login' for BOTH flows AND fired on failure.)
      final eventName = _isLogin ? 'login' : 'signup';
      await ref
          .read(analyticsServiceProvider)
          .logEvent(name: eventName, parameters: {'method': 'email_password'});

      // Set user id + signup method as user properties for cohort analysis.
      await ref
          .read(analyticsServiceProvider)
          .setUserId(
            latestAuthState.value!.backendId?.toString() ??
                latestAuthState.value!.id,
          );

      if (mounted) context.go(AppRoutes.home);
      return;
    }

    if (latestAuthState.hasError) {
      // FAILURE — do NOT fire the login/signup event. The previous version
      // emitted 'login' on every attempt, including failures.
      setState(() {
        _errorMessage = friendlyErrorMessage(latestAuthState.error);
      });
    }
  }

  String? _validateName(String? value) {
    if (_isLogin) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Enter your name.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Enter your password.';
    }
    if (password.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = _errorMessage;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.psychology_rounded,
              onLeadingPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.onboarding);
                }
              },
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    _isLogin ? 'Welcome Back' : 'Join Trenzy',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to sync your decisions and vibes.'
                        : 'Create an account to start saving your edits.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _AuthTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: _validateName,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _AuthTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        _AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          validator: _validatePassword,
                          onSubmitted: (_) {
                            if (!isLoading) {
                              _submit();
                            }
                          },
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TapScale(
                      child: FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isLogin ? 'Sign In' : 'Create Account'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TapScale(
                      child: FilledButton.icon(
                        onPressed: _isGoogleLoading
                            ? null
                            : () async {
                                final router = GoRouter.of(context);
                                setState(() {
                                  _errorMessage = null;
                                  _isGoogleLoading = true;
                                });
                                try {
                                  // 1) Google OAuth -> create a Firebase session
                                  await GoogleSignInService.instance.signIn();

                                  // 2) Sync backend DB user via /api/auth/google-login
                                  await ref
                                      .read(authProvider.notifier)
                                      .googleLogin();
                                } on FirebaseAuthException catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMessage =
                                          e.message ?? 'Google sign-in failed.';
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMessage = e.toString();
                                    });
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isGoogleLoading = false;
                                    });
                                  }
                                }

                                if (!mounted) return;

                                // googleLogin() updates authProvider.
                                final latestAuthState = ref.read(authProvider);
                                final userModel = latestAuthState.value;

                                if (userModel != null) {
                                  final userId =
                                      userModel.backendId?.toString() ??
                                      userModel.id;

                                  await ref
                                      .read(analyticsServiceProvider)
                                      .logEvent(
                                        name: 'signup',
                                        parameters: {'method': 'google'},
                                      );

                                  await ref
                                      .read(analyticsServiceProvider)
                                      .setUserId(userId);

                                  if (!mounted) return;
                                  router.go(AppRoutes.home);
                                  return;
                                }

                                if (latestAuthState.hasError) {
                                  if (!mounted) return;
                                  setState(() {
                                    _errorMessage = friendlyErrorMessage(
                                      latestAuthState.error,
                                    );
                                  });
                                }
                              },
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: _isGoogleLoading
                            ? const Text('Signing in...')
                            : const Text('Continue with Google'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Need an account? Sign up'
                            : 'Already have an account? Sign in',
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: trailing,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
