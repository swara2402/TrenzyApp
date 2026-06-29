import 'package:flutter/foundation.dart';

/// Centralizes API + Socket URLs so the app works across web / Android / iOS.
///
/// Usage:
///  - In production: build with --dart-define=TRENZY_API_BASE_URL=https://api.your-domain.com
///  - In dev: falls back to localhost / 10.0.2.2 automatically.
class EnvConfig {
  /// Override base URL for both HTTP and Socket.IO.
  ///
  /// Examples:
  ///  - 'https://api.trenzy.example.com'
  ///  - 'https://192.168.1.50:8000'
  ///
  /// All production URLs must use https://. Set via:
  ///   flutter build apk --release \
  ///     --dart-define=TRENZY_API_BASE_URL=https://api.trenzy.example.com
  static const String _override = String.fromEnvironment(
    'TRENZY_API_BASE_URL',
    defaultValue: '',
  );
  static String? get apiBaseUrlOverride =>
      _override.isNotEmpty ? _override : null;

  /// Base URL for HTTP endpoints.
  /// (Backend expects /api prefix as used in [ApiService].)
  static String get httpBaseUrl {
    final base = socketBaseUrl;
    return '$base/api';
  }

  /// Base URL for Socket.IO.
  ///
  /// Important:
  ///  - Your backend (uvicorn) is currently serving plain HTTP on port 8000.
  ///  - In release mode, this MUST be overridden via --dart-define or the app
  ///    will throw — we no longer silently fall back to localhost in release
  ///    builds, which would have caused every API call to fail on real devices.
  static String get socketBaseUrl {
    if (apiBaseUrlOverride != null && apiBaseUrlOverride!.isNotEmpty) {
      return apiBaseUrlOverride!;
    }

    // RELEASE MODE: refuse to silently fall back to localhost.
    // The build command MUST pass --dart-define=TRENZY_API_BASE_URL=...
    if (kReleaseMode) {
      throw StateError(
        'TRENZY_API_BASE_URL is not set. Release builds MUST pass it via '
        '--dart-define=TRENZY_API_BASE_URL=https://your-api.example.com',
      );
    }

    // Web: the browser can reach the dev server on localhost via http.
    if (kIsWeb) return 'http://localhost:8000';

    // Android emulator: host machine is reachable at 10.0.2.2
    // Physical devices: override is required.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000';
  }
}
