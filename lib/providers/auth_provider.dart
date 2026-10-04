import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../models/api_exception.dart';
import '../services/api_service.dart';
import '../services/api_service_base.dart';
import '../services/blend_socket_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/feature_flags.dart';
import '../services/dev_auth.dart';
import '../utils/firebase_error_handler.dart';
import 'api_service_provider.dart';

final firebaseAuthProvider = Provider.autoDispose<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});



final authProvider =
    AsyncNotifierProvider.autoDispose<AuthNotifier, UserModel?>(
      () => AuthNotifier(),
    );

class AuthNotifier extends AutoDisposeAsyncNotifier<UserModel?> {
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  ApiServiceBase get _api => ref.read(apiServiceProvider);

  /// Guards against re-entrant calls to _syncBackendUser from the
  /// authStateChanges listener, which could create an infinite loop when
  /// the backend call triggers a token refresh that re-fires the listener.
  bool _isSyncing = false;

  @override
  Future<UserModel?> build() async {
    // Listen to Firebase auth state changes and update provider reactively.
    // Using keepAlive to avoid autoDispose canceling subscription prematurely.
    final link = ref.keepAlive();

    final subscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        if (FeatureFlags.devAuthBypass) {
          state = AsyncValue.data(UserModel(
            id: DevAuth.currentDevUid(),
            name: 'Dev User',
            email: 'dev@trenzy.local',
            emailVerified: true,
          ));
          return;
        }
        // Only update auth state here.
        // Dependent provider invalidation is handled by an external listener.
        state = const AsyncValue.data(null);
      } else {
        // Don't override if we're already loading (e.g. during login() call),
        // and guard against re-entrant sync calls.
        if (!state.isLoading && !_isSyncing) {
          _isSyncing = true;
          try {
            state = AsyncValue.data(await _syncBackendUser(user));
          } finally {
            _isSyncing = false;
          }
        }
      }
    });

    ref.onDispose(() {
      subscription.cancel();
      link.close();
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (FeatureFlags.devAuthBypass) {
        return UserModel(
          id: DevAuth.currentDevUid(),
          name: 'Dev User',
          email: 'dev@trenzy.local',
          emailVerified: true,
        );
      }
      return null;
    }
    return _syncBackendUser(user);
  }

  UserModel _toUserModel(User user) {
    return UserModel.fromFirebase(
      uid: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: user.email ?? '',
    ).copyWith(emailVerified: _isVerified(user));
  }

  bool _isVerified(User user) {
    if (FeatureFlags.devAuthBypass) return true;
    return user.emailVerified;
  }

  Future<UserModel> _syncBackendUser(User user) async {
    try {
      // Force-refresh token to guarantee it's valid before hitting the backend.
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return _toUserModel(user).copyWith(emailVerified: _isVerified(user));
      }

      final backendUser = await _api.getCurrentUser();

      if (backendUser != null) {
        final synced = UserModel.fromJson(backendUser);
        return synced.copyWith(emailVerified: _isVerified(user));
      }
    } on FirebaseAuthException catch (e) {
      // Handle token expired error specifically
      if (e.code == 'user-token-expired') {
        debugPrint('Firebase token expired, user will need to sign in again');
        // Sign out the user to clear invalid state
        await _auth.signOut();
        ApiService.clearCache();
        state = const AsyncValue.data(null);
        rethrow; // Re-throw to allow navigation guards to handle redirect to login
      }
      // Fall back for other Firebase auth errors
    } catch (_) {
      // Fall back to Firebase profile when backend is unreachable / other token
      // retrieval fails. Do NOT rethrow — the user is still authenticated.
    }
    return _toUserModel(user).copyWith(emailVerified: _isVerified(user));
  }

  // NOTE: provider invalidation must not happen here.
  // auth-dependent provider invalidation is handled via [authLifecycleListenerProvider].

  /// Completes Google sign-in + syncs a backend DB user.
  ///
  /// Flow:
  /// 1) Ensures FirebaseAuth has a currentUser (Google sign-in must happen
  ///    before calling this method, e.g. via GoogleSignInService).
  /// 2) Exchanges currentUser ID token with backend /api/auth/google-login
  ///    to upsert the DB user.
  Future<void> googleLogin() async {
    state = const AsyncValue.loading();

    try {
      final user = _auth.currentUser ?? await GoogleSignInService.instance.signIn();

      // Ensure a fresh token before hitting backend.
      await user.getIdToken(true);

      // Best-effort: call backend to upsert DB user.
      await _api.googleLogin();

      final synced = await _syncBackendUser(user);
      state = AsyncValue.data(synced);
    } catch (e, st) {
      final msg = e is FirebaseAuthException
          ? (e.message ?? e.toString())
          : e.toString();
      state = AsyncValue.error(ApiException(msg), st);
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = const AsyncValue.data(null);
      throw const ApiException('Please enter a valid email address');
    }
    if (password.isEmpty) {
      state = const AsyncValue.data(null);
      throw const ApiException('Please enter your password');
    }

    state = const AsyncValue.loading();

    try {
      debugPrint('[Auth] login attempt');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final synced = await _syncBackendUser(user);
      state = AsyncValue.data(synced);
    } catch (e, st) {
      final msg = friendlyFirebaseError(e);
      state = AsyncValue.error(ApiException(msg), st);
      rethrow;
    }
  }

  /// Sends email verification using Firebase SDK as primary method,
  /// falling back to the REST API only if the SDK method fails.
  ///
  /// The SDK's [User.sendEmailVerification] handles token refresh and
  /// ActionCodeSettings automatically across platforms. The REST API
  /// fallback is kept as a contingency for edge cases (e.g., custom
  /// token sign-in on web where the email field may not be set on the
  /// Firebase Auth record).
  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // ── Primary: Firebase SDK method ──────────────────────────────
      // This is more reliable across platforms, handles token refresh
      // automatically, and works with ActionCodeSettings for custom
      // redirect URLs on web.
      await user.sendEmailVerification();
      return;
    } catch (sdkError) {
      // Log the SDK error for debugging, then fall through to REST API.
      debugPrint(
        'Firebase SDK sendEmailVerification failed, '
        'falling back to REST API: $sdkError',
      );
    }

    // ── Fallback: REST API ──────────────────────────────────────────
    // Used when the SDK method fails (e.g., email not set on Firebase
    // Auth record for custom-token users on web).
    try {
      final idToken = await user.getIdToken(true);
      final apiKey = _auth.app.options.apiKey;
      final response = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'VERIFY_EMAIL',
          'idToken': idToken,
        }),
      );
      if (response.statusCode != 200) {
        String message;
        try {
          final body = jsonDecode(response.body);
          message = body['error']?['message']?.toString() ??
              'Failed to send verification email (HTTP ${response.statusCode})';
        } catch (_) {
          message = 'Failed to send verification email (HTTP ${response.statusCode})';
        }
        throw ApiException(message);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // If both methods failed, throw a user-friendly message.
      throw ApiException(
        'Unable to send verification email. Please try again later.',
      );
    }
  }

  Future<void> signup(String name, String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = const AsyncValue.data(null);
      throw const ApiException('Please enter a valid email address');
    }
    if (password.length < 8) {
      state = const AsyncValue.data(null);
      throw const ApiException('Password must be at least 8 characters');
    }

    state = const AsyncValue.loading();

    try {
      debugPrint('[Auth] signup attempt');
      final cred = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      await cred.user?.updateDisplayName(name);

      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        // Keep registration successful even if email dispatch fails temporarily.
        // But log it so developers can diagnose Firebase configuration issues.
        debugPrint('Firebase verification email dispatch failed: $e');
      }

      await _auth.currentUser?.reload();
      final user = _auth.currentUser;

      if (user != null) {
        final synced = await _syncBackendUser(user);
        state = AsyncValue.data(synced);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      final msg = friendlyFirebaseError(e);
      state = AsyncValue.error(ApiException(msg), st);
      rethrow;
    }
  }

  Future<void> verifyAge(DateTime dateOfBirth) async {
    final current = state.valueOrNull;
    if (current == null) {
      throw const ApiException('You must be signed in to verify your age.');
    }

    final result = await _api.verifyAge(dateOfBirth);
    final verified = result['ageVerified'] == true;
    final isMinor = result['isMinor'] == true;
    if (!verified) {
      throw const ApiException('Age verification could not be completed.');
    }

    state = AsyncValue.data(
      UserModel(
        id: current.id,
        name: current.name,
        email: current.email,
        avatarUrl: current.avatarUrl,
        bio: current.bio,
        isFollowing: current.isFollowing,
        ageVerified: true,
        isMinor: isMinor,
      ),
    );
    await _syncBackendUser(_auth.currentUser!);
  }

  Future<void> updateProfile({required String name}) async {
    final current = state.value;
    if (current == null) {
      throw const ApiException('You must be signed in to update your profile.');
    }

    try {
      final updated = await _api.updateProfile(name: name.trim());
      final synced = UserModel.fromJson(updated);
      state = AsyncValue.data(
        synced.copyWith(
          id: current.id,
          email: synced.email.isNotEmpty == true ? synced.email : current.email,
        ),
      );
    } catch (e) {
      // If backend is unavailable, update local state only.
      state = AsyncValue.data(current.copyWith(name: name.trim()));
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && name.trim().isNotEmpty) {
      await firebaseUser.updateDisplayName(name.trim());
    }
  }

  Future<void> logout() async {
    // 1. Disconnect Blend socket before clearing auth
    try {
      BlendSocketService.instance.disconnect();
    } catch (_) {}

    // 2. Sign out of Firebase (triggers authStateChanges listener)
    await _auth.signOut();

    // 3. Clear API cache and tokens
    ApiService.clearCache();

    // 4. Reset auth state
    state = const AsyncValue.data(null);
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updated = _auth.currentUser;
      if (updated != null) {
        final synced = await _syncBackendUser(updated);
        state = AsyncValue.data(synced);
      }
    }
  }

  Future<bool> checkEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (FeatureFlags.devAuthBypass) return true;
    try {
      await user.reload();
      final updated = _auth.currentUser;
      if (updated == null) return false;
      // If email is verified, sync with backend normally
      if (updated.emailVerified) {
        final synced = await _syncBackendUser(updated);
        state = AsyncValue.data(synced);
      } else {
        // If not verified yet, just update the local state without calling backend
        // to avoid token refresh errors that could block verification
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncValue.data(currentState.copyWith(emailVerified: updated.emailVerified));
        }
      }
      return updated.emailVerified;
    } catch (e) {
      // If there's any error (like token expired), still check if user is verified
      // This prevents the verification flow from breaking
      final updated = _auth.currentUser;
      if (updated != null) {
        return updated.emailVerified;
      }
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    await _sendVerificationEmail();
  }

  Future<bool> deleteAccount() async {
    try {
      await _api.deleteAccount();
      await _auth.signOut();
      ApiService.clearCache();
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      return false;
    }
  }
}