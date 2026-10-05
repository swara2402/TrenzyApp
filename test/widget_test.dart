// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// These plugin platform-interface packages are transitively available via
// firebase_core / video_player, but the test references their fakes directly.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:trenzy/app.dart';

const FirebaseOptions _testFirebaseOptions = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: 'test-app-id',
  messagingSenderId: 'test-sender-id',
  projectId: 'test-project-id',
);

class FakeFirebaseApp extends FirebaseAppPlatform {
  FakeFirebaseApp(super.name, super.options);
}

/// In-memory [FirebasePlatform] so widget tests can initialize a default app
/// without any real plugin messaging.
class FakeFirebasePlatform extends FirebasePlatform {
  FakeFirebasePlatform();

  final Map<String, FirebaseAppPlatform> _apps = {};

  @override
  List<FirebaseAppPlatform> get apps => _apps.values.toList();

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    final app = _apps[name];
    if (app == null) {
      throw FirebaseException(
        plugin: 'core',
        code: 'no-app',
        message:
            "No Firebase App '$name' has been created - call Firebase.initializeApp()",
      );
    }
    return app;
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final appName = name ?? defaultFirebaseAppName;
    final app = FakeFirebaseApp(appName, options ?? _testFirebaseOptions);
    _apps[appName] = app;
    return app;
  }
}

/// No-op [VideoPlayerPlatform] so the splash video controller can initialize
/// without a real video plugin.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => const Stream.empty();
}

void main() {
  setUp(() async {
    // The app listens to FirebaseAuth.authStateChanges() on startup, which
    // requires a default Firebase app. Use the fake core platform and mock
    // the auth method channel (signed-out user) for widget tests.
    FirebasePlatform.instance = FakeFirebasePlatform();
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_auth'),
          (call) async {
            // Report a signed-out user for every auth call.
            return null;
          },
        );
    await Firebase.initializeApp(options: _testFirebaseOptions);
  });

  testWidgets('App builds correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: TrenzyApp()));

    // Verify that the app builds without crashing
    expect(tester.takeException(), isNull);

    // Let the splash navigation timers fire so no timer is pending when
    // the test ends.
    await tester.pump(const Duration(seconds: 10));
  });
}
