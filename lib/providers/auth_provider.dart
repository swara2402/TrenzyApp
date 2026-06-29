import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/api_exception.dart';
import '../services/api_service.dart';

final firebaseAuthProvider = Provider.autoDispose<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final apiServiceProvider = Provider.autoDispose<ApiService>((ref) {
  return ApiService(firebaseAuth: FirebaseAuth.instance);
});

final authProvider =
    AsyncNotifierProvider.autoDispose<AuthNotifier, UserModel?>(
      () => AuthNotifier(),
    );

class AuthNotifier extends AutoDisposeAsyncNotifier<UserModel?> {
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<UserModel?> build() async {
    // Listen to Firebase auth state changes and update provider reactively.
    // Using keepAlive to avoid autoDispose canceling subscription prematurely.
    final link = ref.keepAlive();

    final subscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        // Only update auth state here.
        // Dependent provider invalidation is handled by an external listener.
        state = const AsyncValue.data(null);
      } else {
        // Don't override if we're already loading (e.g. during login() call).
        if (!state.isLoading) {
          state = AsyncValue.data(await _syncBackendUser(user));
          // Cache refresh happens via external auth lifecycle listener.
        }
      }
    });

    ref.onDispose(() {
      subscription.cancel();
      link.close();
    });

    final user = _auth.currentUser;
    if (user == null) return null;
    return _syncBackendUser(user);
  }

  UserModel _toUserModel(User user) {
    return UserModel.fromFirebase(
      uid: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: user.email ?? '',
    );
  }

  Future<UserModel> _syncBackendUser(User user) async {
    try {
      // Force-refresh token to guarantee it's valid before hitting the backend.
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        return _toUserModel(user);
      }

      final backendUser = await _api.getCurrentUser();

      if (backendUser != null) {
        final synced = UserModel.fromJson(backendUser);
        if (synced.id.isEmpty) {
          return _toUserModel(user).copyWith(
            backendId: synced.backendId,
            name: synced.name.isNotEmpty ? synced.name : user.displayName ?? '',
            email: synced.email.isNotEmpty ? synced.email : user.email ?? '',
          );
        }
        return synced;
      }
    } catch (_) {
      // Fall back to Firebase profile when backend is unreachable / token
      // retrieval fails. Do NOT rethrow — the user is still authenticated.
    }
    return _toUserModel(user);
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
      final user = _auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }

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
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // On web, Firebase Auth email/password can require recaptcha/enterprise
      // configuration and may fail with 400.
      // Instead, authenticate via the backend (which performs Firebase auth server-side).
      if (const bool.fromEnvironment(
            'dart.library.html',
            defaultValue: false,
          ) ==
          true) {
        // Backend login is not used for session creation on web.
        // Launch correctness requirement: FirebaseAuth MUST have a
        // currentUser so ApiService can attach Authorization bearer tokens.
        // Therefore on web we perform the Firebase client login directly.

        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = _auth.currentUser;
        if (user == null) {
          state = const AsyncValue.data(null);
          return;
        }

        final synced = await _syncBackendUser(user);
        state = AsyncValue.data(synced);
        return;
      }

      // Mobile/desktop: use Firebase directly.
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _auth.currentUser;
      if (user != null) {
        final synced = await _syncBackendUser(user);
        state = AsyncValue.data(synced);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      final msg = e is FirebaseAuthException
          ? (e.message ?? e.toString())
          : e.toString();
      state = AsyncValue.error(ApiException(msg), st);
    }
  }

  Future<void> signup(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
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
      final msg = e is FirebaseAuthException
          ? (e.message ?? e.toString())
          : e.toString();
      state = AsyncValue.error(ApiException(msg), st);
    }
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
          email: synced.email.isNotEmpty ? synced.email : current.email,
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
    await _auth.signOut();
    // This will also be driven by Firebase authStateChanges,
    // but setting state keeps UI responsive immediately.
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
}
