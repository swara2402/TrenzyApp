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
  
  static const bool devAuthBypass = bool.fromEnvironment(
    'FF_DEV_AUTH_BYPASS',
    defaultValue: false,
  );
}