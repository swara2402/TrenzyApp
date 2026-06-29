import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Log app_open — required for beta analytics dashboard.
  if (!kIsWeb) {
    try {
      await FirebaseAnalytics.instance.logAppOpen();
    } catch (_) {
      // Don't block startup if analytics isn't configured.
    }
  }

  // FirebaseCrashlytics must be properly configured on the target platform.
  // If plugin constants are missing, instantiating the Crashlytics singleton
  // can throw an assertion. Guard all Crashlytics usage so the app never
  // instantiates/records when Crashlytics isn't configured.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      // Explicitly enable collection — required on iOS (defaults to disabled
      // until setCrashlyticsCollectionEnabled is called) and recommended on
      // Android for clarity.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      FlutterError.onError = (details) {
        try {
          FirebaseCrashlytics.instance.recordFlutterError(details);
        } catch (_) {
          // Keep the app running if Crashlytics isn't configured.
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        try {
          // Most async errors are non-fatal — flag false so Crashlytics
          // dashboard doesn't mark everything as a crash.
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
        } catch (_) {
          // Keep the app running if Crashlytics isn't configured.
        }
        // Return true to indicate the error was handled.
        return true;
      };
    } catch (_) {
      // If Crashlytics isn't available/configured, keep the app running.
    }
  }

  // Track app open event for beta analytics.
  // (No-op until firebase_analytics is wired; see analytics_service.dart.)
  try {
    // Fire-and-forget — don't block app startup on analytics.
    Future.microtask(() {});
  } catch (_) {
    // ignore
  }

  runApp(ProviderScope(child: TrenzyApp()));
}
