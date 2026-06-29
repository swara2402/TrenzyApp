import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import '../models/user_model.dart';

import 'products_provider.dart';
import 'wishlist_provider.dart';

/// Mounts Riverpod listeners related to auth lifecycle.
///
/// Important: invalidation must NOT happen inside [AuthNotifier] itself,
/// otherwise it can cause circular rebuilds during auth transitions.
final authLifecycleListenerProvider = Provider.autoDispose<void>((ref) {
  ref.listen<AsyncValue<UserModel?>>(authProvider, (prev, next) {
    // When auth changes, invalidate dependent caches.
    // This must not happen inside [AuthNotifier] itself.
    // NOTE: 'prev' can be null depending on Riverpod callback timing,
    // so we only rely on 'next'.
    final nextUser = next.value;

    final wasAuthed = prev?.valueOrNull != null;
    final isAuthed = nextUser != null;

    if (wasAuthed != isAuthed) {
      ref.invalidate(productsProvider);
      ref.invalidate(wishlistProvider);
    }
  });
});
