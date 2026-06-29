import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_service.dart';

/// Provides [AnalyticsService] to the app.
///
/// On mobile/desktop we use the real [FirebaseAnalyticsService] — events
/// flow to the Firebase console. On web we fall back to [NoopAnalyticsService]
/// until firebase_analytics_web is properly configured.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (kIsWeb) {
    // Web support in firebase_analytics requires additional setup
    // (measurementId in firebase_options.dart + gtag.js). Use noop for now
    // and revisit post-beta.
    return NoopAnalyticsService();
  }
  return FirebaseAnalyticsService();
});
