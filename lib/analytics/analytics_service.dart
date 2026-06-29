import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Central analytics abstraction.
///
/// Implementations can be swapped at the provider level
/// (see `analytics_service_provider.dart`).
abstract class AnalyticsService {
  Future<void> logEvent({
    required String name,
    Map<String, Object?> parameters = const {},
  });

  /// Set the current user id on the analytics backend.
  Future<void> setUserId(String? id);

  /// Set a user property (e.g. signup_method, plan_tier).
  Future<void> setUserProperty({required String name, String? value});
}

/// Default no-op implementation. Used as a fallback when Firebase Analytics
/// is not available (e.g. on web debug builds without measurementId).
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?> parameters = const {},
  }) async {
    debugPrint('Analytics (noop) event: $name params=$parameters');
  }

  @override
  Future<void> setUserId(String? id) async {
    debugPrint('Analytics (noop) setUserId: $id');
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    debugPrint('Analytics (noop) setUserProperty: $name=$value');
  }
}

/// Real Firebase Analytics implementation.
///
/// Routes every event to Firebase Analytics (visible in the Firebase console
/// under Analytics → Events). Required for the 20-user beta — without this
/// the founder has zero visibility into what users are doing.
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?> parameters = const {},
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters.cast<String, Object>(),
      );
    } catch (e) {
      debugPrint('FirebaseAnalytics.logEvent failed for "$name": $e');
    }
  }

  @override
  Future<void> setUserId(String? id) async {
    try {
      await _analytics.setUserId(id: id);
    } catch (e) {
      debugPrint('FirebaseAnalytics.setUserId failed: $e');
    }
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('FirebaseAnalytics.setUserProperty failed: $e');
    }
  }
}
