import 'package:flutter/foundation.dart';

/// Simple logger helper to avoid using `print()` in production code.
///
/// If you later introduce a full logging framework, this file can be
/// replaced/adapted centrally.
class AppLogger {
  AppLogger._();

  static void info(String message) {
    // In release builds, Flutter may suppress debug output.
    debugPrint('[INFO] $message');
  }

  static void warning(String message) {
    debugPrint('[WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    final details = <String>['[ERROR] $message'];
    if (error != null) details.add('error=$error');
    if (stackTrace != null) details.add('stackTrace=$stackTrace');
    debugPrint(details.join(' | '));
  }
}

