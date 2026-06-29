import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static String _getEnv(String key, String fallback) {
    // String.fromEnvironment requires const expressions, so on web debug
    // (where the key isn't a compile-time const) we fall back to provided
    // defaults.
    //
    // This keeps the app running for UI/theme work.
    return fallback;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform. '
          'Provide values via --dart-define for FIREBASE_* keys.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _getEnv(
      'FIREBASE_WEB_API_KEY',
      'AIzaSyBMRiWHWzGTDCEfmZ8m8h927jnnU4eTAeM',
    ),
    appId: _getEnv(
      'FIREBASE_WEB_APP_ID',
      '1:262146737740:web:19aa430ab6eebe26b6d6e9',
    ),
    messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID', '262146737740'),
    projectId: _getEnv('FIREBASE_PROJECT_ID', 'trenzy2400'),
    authDomain: _getEnv('FIREBASE_AUTH_DOMAIN', 'trenzy2400.firebaseapp.com'),
    storageBucket: _getEnv(
      'FIREBASE_STORAGE_BUCKET',
      'trenzy2400.firebasestorage.app',
    ),
    measurementId: _getEnv('FIREBASE_MEASUREMENT_ID', 'G-0EWF8FCQV8'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _getEnv(
      'FIREBASE_ANDROID_API_KEY',
      'AIzaSyB_owu_-gg4KGVjo11Lq8pGUSHj5xFQ_YI',
    ),
    appId: _getEnv(
      'FIREBASE_ANDROID_APP_ID',
      '1:262146737740:android:187c3407ac2ef8a8b6d6e9',
    ),
    messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID', '262146737740'),
    projectId: _getEnv('FIREBASE_PROJECT_ID', 'trenzy2400'),
    storageBucket: _getEnv(
      'FIREBASE_STORAGE_BUCKET',
      'trenzy2400.firebasestorage.app',
    ),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _getEnv(
      'FIREBASE_IOS_API_KEY',
      'AIzaSyBT_8bM43Ln5ZSZe6DefCQlUyPMv5iQs4s',
    ),
    appId: _getEnv(
      'FIREBASE_IOS_APP_ID',
      '1:262146737740:ios:b1fe623c4137ffc6b6d6e9',
    ),
    messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID', '262146737740'),
    projectId: _getEnv('FIREBASE_PROJECT_ID', 'trenzy2400'),
    storageBucket: _getEnv(
      'FIREBASE_STORAGE_BUCKET',
      'trenzy2400.firebasestorage.app',
    ),
    iosBundleId: _getEnv('FIREBASE_IOS_BUNDLE_ID', 'com.trenzy.trenzy'),
  );
}
