import 'package:flutter/foundation.dart';

import 'feature_flags.dart' show FeatureFlags;

class EnvConfig {
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

  static String get _defaultApiBaseUrl {
    if (kReleaseMode) {
      // The previous default (https://api.trenzy.com) pointed at a dead
      // host. Release builds must now be given an explicit backend URL at
      // build time so they fail loudly instead of silently routing to a
      // phantom server.
      throw StateError(
        'Release builds require a backend host. Pass '
        '--dart-define=TRENZY_API_BASE_URL=https://<host> '
        'or --dart-define=FF_API_URL_OVERRIDE=https://<host>.',
      );
    }
    // Debug mode: use http://127.0.0.1:8000 (with adb reverse tcp:8000 tcp:8000 on Android)
    return 'http://127.0.0.1:8000';
  }
}