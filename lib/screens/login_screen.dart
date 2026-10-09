import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/api_exception.dart';
import '../providers/auth_provider.dart';
import '../providers/api_service_provider.dart';
import '../router/app_router.dart';
import '../services/feature_flags.dart';
import '../theme/glass_theme.dart';
import '../utils/placeholder_image.dart';
import '../utils/firebase_error_handler.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  double _x = 0;
  double _y = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late final AnimationController _entryController;
  late final Animation<double> _emailSlide;
  late final Animation<double> _passwordSlide;
  late final Animation<double> _loginButtonSlide;
  late final Animation<double> _googleButtonSlide;
  late final Animation<double> _formOpacity;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _emailSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _passwordSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _loginButtonSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _googleButtonSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.45, 0.95, curve: Curves.easeOutCubic),
      ),
    );
    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateMousePosition(PointerEvent details) {
    setState(() {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      _x = (details.position.dx - screenWidth / 2) / screenWidth;
      _y = (details.position.dy - screenHeight / 2) / screenHeight;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      final user = ref.read(authProvider).valueOrNull;
      final isEmailVerified = (user?.emailVerified ?? false) || FeatureFlags.devAuthBypass;
      if (user != null && !isEmailVerified) {
        context.go(AppRoutes.verifyEmail);
      } else {
        await _routeAfterLogin();
      }
    } catch (e) {
      if (!mounted) return;
      final message = friendlyFirebaseError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.trenzyColors.crimson,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _routeAfterLogin() async {
    try {
      final preferences = await ref.read(apiServiceProvider).getPreferences();
      if (!mounted) return;
      context.go(
        AppRoutes.routeFromPreferencesResponse(preferences, source: 'signup'),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        // ApiClient's session-expired callback owns sign-out and routing.
        return;
      }
      if (error.statusCode == 403 &&
          error.message == 'AGE_VERIFICATION_REQUIRED') {
        context.go(AppRoutes.ageVerification);
        return;
      }
      _showPreferencesRetry(error);
    } catch (error) {
      if (mounted) _showPreferencesRetry(error);
    }
  }

  void _showPreferencesRetry(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not load your account progress: $error'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _routeAfterLogin(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: MouseRegion(
        onHover: _updateMousePosition,
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: offlinePlaceholderBackground(
                text: 'Trenzy',
                background: context.trenzyColors.background,
                foreground: context.trenzyColors.mutedFg,
              ),
            ),
            // Gradient Overlays
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.trenzyColors.background,
                    Colors.transparent,
                    context.trenzyColors.background,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_x * 0.1)
                    ..rotateX(-_y * 0.1),
                  alignment: FractionalOffset.center,
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(32.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.graphite.withAlpha(179),
                        borderRadius: BorderRadius.circular(32.0),
                        border: Border.all(color: context.trenzyColors.foreground.withAlpha(13)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Trenzy',
                            style: GlassTypography.display(
                              fontSize: 48,
                              color: context.trenzyColors.primary,
                              weight: FontWeight.w700,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  blurRadius: 20.0,
                                  color: context.trenzyColors.primary,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          MetaLabel(
                            'Curation of the Avant-Garde'.toUpperCase(),
                            color: context.trenzyColors.mutedFg.withAlpha(204),
                            fontSize: 10,
                          ),
                          SizedBox(height: 40),
                          AnimatedBuilder(
                            animation: _entryController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _formOpacity.value,
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Transform.translate(
                                        offset: Offset(0, _emailSlide.value),
                                          child: _buildTextField(
                                          key: const Key('email-field'),
                                          label: 'EMAIL',
                                          icon: Icons.person_outline,
                                          placeholder: 'Enter your email',
                                          controller: _emailController,
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
                                      ),
                                      SizedBox(height: 16),
                                      Transform.translate(
                                        offset: Offset(0, _passwordSlide.value),
                                        child: _buildTextField(
                                          key: const Key('password-field'),
                                          label: 'PASSWORD',
                                          icon: Icons.lock_outline,
                                          placeholder: '••••••••',
                                          isPassword: true,
                                          controller: _passwordController,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            if (value.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      Transform.translate(
                                        offset: Offset(0, _loginButtonSlide.value),
                                        child: GlowButton(
                                          key: const Key('login-button'),
                                          label: 'Sign In'.toUpperCase(),
                                          onTap: _isLoading ? null : _handleLogin,
                                          loading: _isLoading,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go(AppRoutes.forgotPassword),
                              child: Text(
                                'Forgot Password?',
                                style: GlassTypography.body(
                                  fontSize: 12,
                                  color: context.trenzyColors.mutedFg,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _entryController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _googleButtonSlide.value),
                                child: Opacity(
                                  opacity: _formOpacity.value,
                                  child: Column(
                                    children: [
                                      SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(child: Divider(color: context.trenzyColors.glassBorder)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: MetaLabel(
                                              'or continue with'.toUpperCase(),
                                              color: context.trenzyColors.mutedFg,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Expanded(child: Divider(color: context.trenzyColors.glassBorder)),
                                        ],
                                      ),
                                      SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GlowButton(
                                              label: 'Google'.toUpperCase(),
                                              onTap: () async {
                                                try {
                                                  await ref.read(authProvider.notifier).googleLogin();

                                                  if (!mounted) return;

                                                  final user = ref.read(authProvider).valueOrNull;
                                                  final isEmailVerified =
                                                      (user?.emailVerified ?? false) ||
                                                      FeatureFlags.devAuthBypass;
                                                  final shouldVerifyEmail =
                                                      user != null && !isEmailVerified;

                                                  if (shouldVerifyEmail) {
                                                    if (!mounted) return;
                                                    // ignore: use_build_context_synchronously
                                                    context.go(AppRoutes.verifyEmail);
                                                    return;
                                                  }

                                                  // Check if user has completed onboarding preferences
                                                  try {
                                                    final api = ref.read(apiServiceProvider);
                                                    final prefs = await api.getPreferences();

                                                    if (!mounted) return;

                                                    final saved = prefs['preferences'];
                                                    final hasPreferences = saved is Map &&
                                                        ((saved['preferred_categories'] as List?)?.isNotEmpty == true ||
                                                            (saved['preferred_styles'] as List?)?.isNotEmpty == true ||
                                                            (saved['shopping_priorities'] as List?)?.isNotEmpty == true);

                                                    if (hasPreferences) {
                                                      if (!mounted) return;
                                                      // ignore: use_build_context_synchronously
                                                      context.go(AppRoutes.home);
                                                    } else {
                                                      // Start onboarding preference flow from Step 1
                                                      if (!mounted) return;
                                                      // ignore: use_build_context_synchronously
                                                      context.go(
                                                          '${AppRoutes.favoriteCategories}?source=signup');
                                                    }
                                                  } catch (_) {
                                                    if (!mounted) return;
                                                    // If we can't fetch preferences, start onboarding flow to be safe
                                                    // ignore: use_build_context_synchronously
                                                    context.go(
                                                        '${AppRoutes.favoriteCategories}?source=signup');
                                                  }
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  final message = friendlyFirebaseError(e);
                                                  // ignore: use_build_context_synchronously
                                                  final crimsonColor = context.trenzyColors.crimson;
                                                  // ignore: use_build_context_synchronously
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(message),
                                                      backgroundColor: crimsonColor,
                                                      behavior: SnackBarBehavior.floating,
                                                      margin: const EdgeInsets.all(16),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: Icons.public,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GlassTypography.body(
                                  color: context.trenzyColors.mutedFg.withAlpha(153),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(AppRoutes.signUp),
                                child: Text(
                                  'Join the circle',
                                  style: GlassTypography.body(
                                    color: context.trenzyColors.primary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required String label,
    required IconData icon,
    required String placeholder,
    bool isPassword = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaLabel(label, color: context.trenzyColors.mutedFg.withAlpha(153), fontSize: 12),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          validator: validator,
          style: GlassTypography.body(color: context.trenzyColors.foreground),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.trenzyColors.graphite,
            prefixIcon: Icon(icon, color: context.trenzyColors.mutedFg.withAlpha(102)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
                      child: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        key: ValueKey(_obscurePassword),
                        color: context.trenzyColors.mutedFg.withAlpha(102),
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  )
                : null,
            hintText: placeholder,
            hintStyle: GlassTypography.body(color: context.trenzyColors.mutedFg.withAlpha(102)),
            errorStyle: GlassTypography.body(
              color: context.trenzyColors.crimson,
              fontSize: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.trenzyColors.glassBorder.withAlpha(77)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.trenzyColors.glassBorder.withAlpha(77)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.trenzyColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.trenzyColors.crimson.withAlpha(153)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.trenzyColors.crimson),
            ),
          ),
        ),
      ],
    );
  }
}