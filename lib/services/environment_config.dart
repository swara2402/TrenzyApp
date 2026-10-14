import 'feature_flags.dart' show FeatureFlags;

class EnvConfig {
  static const String liveBackendUrl =
      'https://trenzy-staging-api.onrender.com';

  static const String _override = String.fromEnvironment(
    'TRENZY_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl => FeatureFlags.apiUrlOverride.isNotEmpty
      ? FeatureFlags.apiUrlOverride
      : _override.isNotEmpty
      ? _override
      : _defaultApiBaseUrl;

  static String get socketBaseUrl => FeatureFlags.apiUrlOverride.isNotEmpty
      ? FeatureFlags.apiUrlOverride
      : _override.isNotEmpty
      ? _override
      : _defaultApiBaseUrl;

  static const bool useMockApi = bool.fromEnvironment(
    'TRENZY_USE_MOCK_API',
    defaultValue: false,
  );

  static bool get isMockMode => useMockApi;

  static String get _defaultApiBaseUrl => liveBackendUrl;
}
