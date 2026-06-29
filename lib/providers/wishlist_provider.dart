import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class WishlistState {
  const WishlistState({required this.productIds, this.isLoaded = false});

  final List<String> productIds;
  final bool isLoaded;

  // Remove unused `copyWith` method

  bool contains(String productId) => productIds.contains(productId);
}

class WishlistNotifier extends AutoDisposeAsyncNotifier<WishlistState> {
  @override
  Future<WishlistState> build() async {
    // Keep alive so wishlist persists across tab switches.
    final link = ref.keepAlive();
    ref.onDispose(() => link.close());

    final auth = ref.watch(authProvider);
    final user = auth.value;
    if (user == null) return const WishlistState(productIds: []);

    final api = ref.watch(apiServiceProvider);
    try {
      final raw = await api.getWishlist();
      final productIds =
          (raw['productIds'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      return WishlistState(productIds: productIds, isLoaded: true);
    } catch (e) {
      debugPrint('Wishlist fetch failed: $e');
      // Return empty rather than crashing — user can still toggle items.
      return const WishlistState(productIds: [], isLoaded: true);
    }
  }

  /// Toggle a product in the wishlist. Optimistic update + background sync.
  Future<void> toggle(String productId) async {
    final current = state.valueOrNull ?? const WishlistState(productIds: []);
    final currentlyIn = current.productIds.contains(productId);

    // Optimistic update.
    final updatedIds = currentlyIn
        ? current.productIds.where((id) => id != productId).toList()
        : [productId, ...current.productIds];
    state = AsyncValue.data(
      WishlistState(productIds: updatedIds, isLoaded: current.isLoaded),
    );

    // Background sync.
    final api = ref.read(apiServiceProvider);
    try {
      await api.setWishlist(updatedIds);
    } catch (e) {
      debugPrint('Wishlist sync failed: $e');
      state = AsyncValue.data(current);
    }
  }

  /// Check if a product is wishlisted (sync, for use in build methods).
  bool isWishlisted(String productId) {
    return (state.valueOrNull?.productIds ?? []).contains(productId);
  }
}

final wishlistProvider =
    AsyncNotifierProvider.autoDispose<WishlistNotifier, WishlistState>(
      () => WishlistNotifier(),
    );
