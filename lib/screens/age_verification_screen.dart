import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

class AgeVerificationScreen extends ConsumerStatefulWidget {
  const AgeVerificationScreen({super.key});
  @override
  ConsumerState<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends ConsumerState<AgeVerificationScreen> {
  DateTime? _dob;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Already-verified users (resumed session, restored state) must never sit
    // on this screen — the router alone can miss the window before the auth
    // sync resolves, so bail out here as well.
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfVerified());
  }

  void _leaveIfVerified() {
    if (!mounted) return;
    final verified =
        ref.read(authProvider).valueOrNull?.ageVerified ?? false;
    if (verified) context.go(AppRoutes.home);
  }

  DateTime _latestAllowedDob() {
    final n = DateTime.now();
    return DateTime(n.year - 13, n.month, n.day);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _latestAllowedDob(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date of birth',
      confirmText: 'Continue',
    );
    if (picked != null) setState(() { _dob = picked; _error = null; });
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') ||
        message.contains('connection failed') ||
        message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup')) {
      return "We couldn't connect to Trenzy right now. Check your internet connection and try again.";
    }
    if (message.contains('13 and older') || message.contains('13+')) {
      return 'Trenzy is available to users aged 13 and older.';
    }
    return 'We couldn’t verify your age right now. Please try again.';
  }

  Future<void> _submit() async {
    final dob = _dob;
    if (dob == null) {
      setState(() => _error = 'Please select your date of birth.');
      return;
    }
    if (dob.isAfter(_latestAllowedDob())) {
      setState(() => _error = 'Trenzy is available to users aged 13 and older.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).verifyAge(dob);
      if (mounted) context.go(AppRoutes.onboarding);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;
    final label = _dob == null
        ? 'Select date of birth'
        : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}';
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 42, color: c.primary),
                  const SizedBox(height: 24),
                  DisplayText('One last safety check.', fontSize: 34),
                  const SizedBox(height: 12),
                  Text(
                    'Trenzy is 13+. Enter your date of birth to continue. '
                    'Your exact date of birth is kept private.',
                    style: GlassTypography.body(color: c.mutedFg, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  InkWell(
                    onTap: _loading ? null : _pick,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.fg08,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: c.primary),
                          const SizedBox(width: 16),
                          Expanded(child: Text(label, style: GlassTypography.body(color: c.foreground, fontSize: 16))),
                          Icon(Icons.calendar_month_outlined, color: c.mutedFg),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: GlassTypography.body(color: c.crimson, fontSize: 14)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: GlowButton(
                      label: _loading ? 'Verifying...' : (_error == null ? 'Continue' : 'Try again'),
                      onTap: _loading ? null : _submit,
                      icon: _loading ? Icons.hourglass_top : Icons.arrow_forward,
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
