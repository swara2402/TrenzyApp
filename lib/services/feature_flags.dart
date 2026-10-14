import 'package:flutter/foundation.dart' show kDebugMode;

class FeatureFlags {
  const FeatureFlags._();

  static const bool blendEnabled = bool.fromEnvironment(
    'FF_BLEND_ENABLED',
    defaultValue: true,
  );

  static const bool paymentsEnabled = bool.fromEnvironment(
    'FF_PAYMENTS_ENABLED',
    // Cart/Checkout are post-launch; opt in explicitly for future builds.
    defaultValue: false,
  );

  static const bool notificationsEnabled = bool.fromEnvironment(
    'FF_NOTIFICATIONS_ENABLED',
    defaultValue: true,
  );

  static const bool recommendationsEnabled = bool.fromEnvironment(
    'FF_RECOMMENDATIONS_ENABLED',
    defaultValue: true,
  );

  static const bool analyticsEnabled = bool.fromEnvironment(
    'FF_ANALYTICS_ENABLED',
    defaultValue: true,
  );

  static const bool debugShowErrors = bool.fromEnvironment(
    'FF_DEBUG_SHOW_ERRORS',
    defaultValue: false,
  );

  static const String apiUrlOverride = String.fromEnvironment(
    'FF_API_URL_OVERRIDE',
    defaultValue: '',
  );

  /// Full dev-auth bypass: skips real Firebase auth entirely and injects a
  /// synthetic DevAuth user. Keeps age verification and onboarding bypassed too.
  /// Only meant for local development with no real Firebase project.
  /// Enable with: --dart-define=FF_DEV_AUTH_BYPASS=true
  static const bool devAuthBypass = bool.fromEnvironment(
    'FF_DEV_AUTH_BYPASS',
    defaultValue: bool.fromEnvironment('DEV_AUTH_BYPASS', defaultValue: false),
  );

  /// Skip the Firebase email-verification gate for beta / debug builds.
  ///
  /// Firebase email/password accounts are not auto-verified, which would
  /// permanently trap real beta testers on VerifyEmailScreen. This flag
  /// bypasses that specific gate while keeping real Firebase auth, age
  /// verification, and onboarding fully intact.
  ///
  /// Automatically `true` in debug builds. Can be overridden:
  ///   --dart-define=FF_SKIP_EMAIL_VERIFICATION=false  (force full verification)
  ///   --dart-define=FF_SKIP_EMAIL_VERIFICATION=true   (force skip in release)
  static bool get skipEmailVerification {
    if (devAuthBypass) return true;
    const skipEmail = bool.fromEnvironment(
      'FF_SKIP_EMAIL_VERIFICATION',
      defaultValue: false,
    );
    if (skipEmail) return true;
    return kDebugMode;
  }
}
