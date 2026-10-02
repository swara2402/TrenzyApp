import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service_base.dart';
import '../providers/api_service_provider.dart';

abstract class AnalyticsService {
  Future<void> logEvent({
    required String name,
    Map<String, Object?> parameters = const {},
  });

  Future<void> setUserId(String? id);

  Future<void> setUserProperty({required String name, String? value});
}

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

class BackedAnalyticsService implements AnalyticsService {
  final AnalyticsService _inner;
  final ApiServiceBase _api;

  BackedAnalyticsService(this._inner, this._api);

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?> parameters = const {},
  }) async {
    await _inner.logEvent(name: name, parameters: parameters);
    try {
      await _api.createActivity(
        kind: name,
        description: parameters.toString(),
        metadataJson: parameters.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (_) {}
  }

  @override
  Future<void> setUserId(String? id) async {
    await _inner.setUserId(id);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    await _inner.setUserProperty(name: name, value: value);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (kIsWeb) {
    return NoopAnalyticsService();
  }
  final api = ref.read(apiServiceProvider);
  return BackedAnalyticsService(FirebaseAnalyticsService(), api);
});
