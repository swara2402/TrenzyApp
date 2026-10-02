import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/utils/firebase_error_handler.dart';
import 'package:trenzy/services/feature_flags.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = step;
      _errorMessage = null;
    });
  }

  Future<void> _finalize() async {
    if (!_formKeyStep3.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).signup(name, email, password);
      if (!mounted) return;
      final user = ref.read(authProvider).valueOrNull;
      if (user != null && !user.emailVerified && !FeatureFlags.devAuthBypass) {
        context.go(AppRoutes.verifyEmail);
      } else {
        // Start onboarding from Step 1, mark source for back-navigation
        context.go('${AppRoutes.favoriteCategories}?source=signup');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = friendlyFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      body: Row(
        children: [
          if (isWide) _buildSidePanel(),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(
                      height: 64,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isWide)
                            Image.asset('assets/logo/app_logo.png', height: 36),
                          Spacer(),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: RichText(
                              text: TextSpan(
                                text: 'ALREADY A MEMBER? ',
                                style: GlassTypography.meta(
                                  fontSize: 11,
                                  color: context.trenzyColors.mutedFg,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'LOG IN',
                                    style: GlassTypography.meta(
                                      fontSize: 11,
                                      color: context.trenzyColors.primary
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    _StepIndicator(currentStep: _currentStep),
                    SizedBox(height: 40),
                    Expanded(
                      child: IndexedStack(
                        index: _currentStep,
                        children: [
                          _Step1(
                            formKey: _formKeyStep1,
                            nameController: _nameController,
                            onContinue: () {
                              if (_formKeyStep1.currentState!.validate()) {
                                _goToStep(1);
                              }
                            },
                          ),
                          _Step2(
                            formKey: _formKeyStep2,
                            emailController: _emailController,
                            onContinue: () {
                              if (_formKeyStep2.currentState!.validate()) {
                                _goToStep(2);
                              }
                            },
                            onBack: () => _goToStep(0),
                          ),
                          _Step3(
                            formKey: _formKeyStep3,
                            passwordController: _passwordController,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            onContinue: _finalize,
                            onBack: () => _goToStep(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Expanded(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.trenzyColors.graphite,
                  Color(0xFF1E1A10),
                  context.trenzyColors.background,
                ],
              ),
            ),
          ),
          // Decorative gradient auras
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
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
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1A2ECC71),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/logo/app_logo.png', height: 48),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.trenzyColors.fg08,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.trenzyColors.glassBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DisplayText(
                                'Curating the future of personal style.',
                                fontSize: 28,
                                weight: FontWeight.bold,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Join an exclusive community of fashion enthusiasts and digital tastemakers.',
                                style: GlassTypography.body(
                                  fontSize: 16,
                                  color: context.trenzyColors.mutedFg,
                                ),
                              ),
                              SizedBox(height: 24),
                              Row(
                                children: [
                                  _FeaturePill(icon: Icons.auto_awesome, label: 'AI Styling'),
                                  SizedBox(width: 8),
                                  _FeaturePill(icon: Icons.groups, label: 'Social'),
                                  SizedBox(width: 8),
                                  _FeaturePill(icon: Icons.explore, label: 'Discovery'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.trenzyColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.trenzyColors.primary),
          SizedBox(width: 4),
          Text(
            label,
            style: GlassTypography.meta(
              fontSize: 11,
              color: context.trenzyColors.primary
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(3, (index) {
            final isActive = currentStep >= index;
            return Expanded(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 400),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive ? context.trenzyColors.primary : context.trenzyColors.fg10,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: context.trenzyColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final labels = ['Discovery', 'Connectivity', 'Security'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                labels[index],
                style: GlassTypography.meta(
                  fontSize: 10,
                  color: currentStep == index
                      ? context.trenzyColors.primary
                      : context.trenzyColors.mutedFg.withValues(alpha: 0.5),
                  
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Step1 extends StatefulWidget {
  const _Step1({
    required this.formKey,
    required this.nameController,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final VoidCallback onContinue;

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetaLabel('STEP 1 OF 3', fontSize: 11),
            SizedBox(height: 8),
            DisplayText('Who are you?', fontSize: 32),
            SizedBox(height: 8),
            Text(
              'Let\'s get to know you a bit.',
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
            SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.fg08,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.trenzyColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 40,
                          color: context.trenzyColors.primary
                        ),
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: widget.nameController,
                        style: GlassTypography.body(color: context.trenzyColors.foreground),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: GlassTypography.body(color: context.trenzyColors.mutedFg),
                          filled: true,
                          fillColor: context.trenzyColors.graphite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.primary),
                          ),
                          counterText: '',
                        ),
                        maxLength: 50,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                label: 'Continue',
                onTap: widget.onContinue,
                icon: Icons.arrow_forward,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step2 extends StatefulWidget {
  const _Step2({
    required this.formKey,
    required this.emailController,
    required this.onContinue,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetaLabel('STEP 2 OF 3', fontSize: 11),
            SizedBox(height: 8),
            DisplayText('Your Gateway.', fontSize: 32),
            SizedBox(height: 8),
            Text(
              'Enter your email to get started.',
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
            SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.fg08,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.trenzyColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.emerald.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 40,
                          color: context.trenzyColors.emerald,
                        ),
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: widget.emailController,
                        style: GlassTypography.body(color: context.trenzyColors.foreground),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: GlassTypography.body(color: context.trenzyColors.mutedFg),
                          filled: true,
                          fillColor: context.trenzyColors.graphite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.emerald),
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
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            Row(
              children: [
                GlassBackButton(onTap: widget.onBack),
                SizedBox(width: 16),
                Expanded(
                  child: GlowButton(
                    label: 'Define Password',
                    onTap: widget.onContinue,
                    icon: Icons.arrow_forward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step3 extends StatefulWidget {
  const _Step3({
    required this.formKey,
    required this.passwordController,
    required this.isLoading,
    this.errorMessage,
    required this.onContinue,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  String _passwordText = '';
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordText = widget.passwordController.text;
    widget.passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordText = widget.passwordController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetaLabel('STEP 3 OF 3', fontSize: 11),
            SizedBox(height: 8),
            DisplayText('Secure Access.', fontSize: 32),
            SizedBox(height: 8),
            Text(
              'Create a strong password to protect your account.',
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
            SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.fg08,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.trenzyColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.crimson.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 40,
                          color: context.trenzyColors.crimson,
                        ),
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: widget.passwordController,
                        style: GlassTypography.body(color: context.trenzyColors.foreground),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: GlassTypography.body(color: context.trenzyColors.mutedFg),
                          filled: true,
                          fillColor: context.trenzyColors.graphite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.trenzyColors.crimson),
                          ),
                          suffixIcon: Semantics(
                            label: _passwordVisible ? 'Hide password' : 'Show password',
                            child: IconButton(
                              icon: Icon(
                                _passwordVisible ? Icons.visibility_off : Icons.visibility,
                                color: context.trenzyColors.mutedFg,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        obscureText: !_passwordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          _PasswordRequirement(
                            label: '8+ characters',
                            met: _passwordText.length >= 8,
                          ),
                          SizedBox(width: 12),
                          _PasswordRequirement(
                            label: 'Has uppercase',
                            met: _passwordText.length >= 8 && _passwordText != _passwordText.toLowerCase(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.errorMessage != null) ...[
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.trenzyColors.crimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.trenzyColors.crimson.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: context.trenzyColors.crimson,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: GlassTypography.body(
                          fontSize: 13,
                          color: context.trenzyColors.crimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 24),
            Row(
              children: [
                GlassBackButton(onTap: widget.onBack),
                SizedBox(width: 16),
                Expanded(
                  child: GlowButton(
                    label: 'Create Account',
                    onTap: widget.isLoading ? null : widget.onContinue,
                    loading: widget.isLoading,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'By joining, you agree to our ',
                  style: GlassTypography.meta(
                    fontSize: 11,
                    color: context.trenzyColors.mutedFg,
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push(AppRoutes.termsOfService),
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

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool met;

  const _PasswordRequirement({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${met ? 'Requirement met' : 'Requirement not met'}: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: met ? context.trenzyColors.emerald : context.trenzyColors.mutedFg.withValues(alpha: 0.5),
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: GlassTypography.meta(
              fontSize: 10,
              color: met ? context.trenzyColors.emerald : context.trenzyColors.mutedFg.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}