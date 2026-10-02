import 'dart:convert';
import 'package:crypto/crypto.dart';

class DevAuth {
  DevAuth._();

  static const String _devUid = String.fromEnvironment(
    'DEV_AUTH_UID',
    defaultValue: 'dev-user-123',
  );

  static const String _devSecret = String.fromEnvironment(
    'DEV_AUTH_SECRET',
    defaultValue: 'test-dev-secret',
  );

  /// Resolves which dev identity this page should act as.
  ///
  /// Defaults to the compile-time DEV_AUTH_UID, but supports a per-page
  /// override via a `?devUid=<uid>` query parameter (survives hash routing,
  /// so `http://localhost:8090/?devUid=demo-user-1#/home` works). This lets a
  /// local demo act as a second real member over live sockets instead of
  /// faking them. Only meaningful when the dev bypass is enabled; in normal
  /// builds this path is never used.
  static String currentDevUid() {
    const fallback = _devUid;
    try {
      final override = Uri.base.queryParameters['devUid'];
      if (override != null && override.trim().isNotEmpty) {
        return override.trim();
      }
    } catch (_) {}
    return fallback;
  }

  /// Mints a backend dev-bypass token of the form
  /// `dev-token-{uid}:{hmac_sha256(secret, uid)}`, mirroring the backend's
  /// `app.firebase_auth.mint_dev_token` so the local demo backend accepts it.
  /// Must match the backend's configured DEV_AUTH_UID / DEV_AUTH_SECRET.
  static String devToken() => devTokenFor(currentDevUid());

  /// Mints a dev-bypass token for an explicit uid (any identity in the
  /// backend's DEV_AUTH_USERS allowlist).
  static String devTokenFor(String uid) {
    final hmac = Hmac(sha256, utf8.encode(_devSecret));
    final signature = hmac.convert(utf8.encode(uid)).toString();
    return 'dev-token-$uid:$signature';
  }
}