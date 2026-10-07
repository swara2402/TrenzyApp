import 'dart:io' show Platform;
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
    // Debug mode: use 10.0.2.2 for Android emulator to reach host localhost
    // (127.0.0.1 on the emulator points to the emulator itself). iOS Simulator
    // can also use 127.0.0.1; desktop too. If adb reverse is set up this may
    // vary, but 10.0.2.2 is the most reliable for Android emulator.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}