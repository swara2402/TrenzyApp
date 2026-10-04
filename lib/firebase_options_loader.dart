import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseOptionsLoader {
  static const String assetPath = 'assets/firebase_options.json';

  /// Fields that must NOT contain placeholder values.
  static const _placeholders = {'REPLACE_ME', 'com.yourcompany.trenzy', 'CHANGE_ME'};

  /// Loads FirebaseOptions for the current platform from a bundled JSON asset.
  ///
  /// Throws [StateError] if required fields are missing or still contain
  /// placeholder values such as "REPLACE_ME".
  ///
  /// How to fill in missing values:
  ///   1. Open the Firebase Console → Project Settings → Your apps.
  ///   2. Register the Android / iOS / macOS app if you haven't yet.
  ///   3. Copy the appId (e.g. "1:262146737740:android:xxxxx").
  ///   4. For iOS/macOS also copy the OAuth 2.0 client ID (iosClientId)
  ///      and your bundle ID (iosBundleId).
  ///   5. Paste the values into assets/firebase_options.json.
  static Future<FirebaseOptions> loadForCurrentPlatform() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final String key;
    if (kIsWeb) {
      key = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          key = 'android';
          break;
        case TargetPlatform.iOS:
          key = 'ios';
          break;
        case TargetPlatform.macOS:
          key = 'macos';
          break;
        case TargetPlatform.windows:
          key = 'windows';
          break;
        case TargetPlatform.linux:
          key = 'linux';
          break;
        default:
          throw UnsupportedError('Unsupported platform for Firebase options.');
      }
    }

    final platformMap = decoded[key];
    if (platformMap == null || platformMap is! Map<String, dynamic>) {
      throw StateError(
        'Missing "$key" Firebase options in $assetPath. '
        'Register the app in Firebase Console and update the asset file.',
      );
    }

    // Validate that no critical field still holds a placeholder value.
    _validatePlatformConfig(key, platformMap);

    return FirebaseOptions(
      apiKey: platformMap['apiKey'] as String,
      appId: platformMap['appId'] as String,
      messagingSenderId: platformMap['messagingSenderId'] as String,
      projectId: platformMap['projectId'] as String,
      authDomain: platformMap['authDomain'] as String?,
      storageBucket: platformMap['storageBucket'] as String?,
      measurementId: platformMap['measurementId'] as String?,
      iosClientId: platformMap['iosClientId'] as String?,
      iosBundleId: platformMap['iosBundleId'] as String?,
    );
  }

  /// Validates that required fields are present and not placeholders.
  ///
  /// Required for every platform: apiKey, appId, messagingSenderId, projectId.
  /// Required for iOS/macOS additionally: iosClientId, iosBundleId.
  static void _validatePlatformConfig(
    String platform,
    Map<String, dynamic> config,
  ) {
    final requiredFields = ['apiKey', 'appId', 'messagingSenderId', 'projectId'];
    if (platform == 'ios' || platform == 'macos') {
      requiredFields.addAll(['iosClientId', 'iosBundleId']);
    }

    for (final field in requiredFields) {
      final value = config[field] as String?;
      if (value == null || value.isEmpty) {
        throw StateError(
          'Firebase config error: "$field" is missing for platform "$platform" '
          'in $assetPath. '
          'Open Firebase Console → Project Settings → Your apps and copy the value.',
        );
      }
      if (_placeholders.any((p) => value.contains(p))) {
        throw StateError(
          'Firebase config error: "$field" still contains a placeholder '
          '("$value") for platform "$platform" in $assetPath. '
          'Replace it with the real value from Firebase Console.',
        );
      }
    }
  }
}
