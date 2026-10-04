import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart' as auth_p;
import 'api_service_provider.dart';

class WishlistState {
  const WishlistState({required this.productIds, this.isLoaded = false});

  final Set<String> productIds;
  final bool isLoaded;

  bool contains(String productId) => productIds.contains(productId);
}

class WishlistNotifier extends AutoDisposeAsyncNotifier<WishlistState> {
  @override
  Future<WishlistState> build() async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
    if (uid == null) {
      return const WishlistState(productIds: {}, isLoaded: true);
    }

    final api = ref.read(apiServiceProvider);
    try {
      final raw = await api.getWishlist();
      final ids = (raw['productIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{};
      return WishlistState(productIds: ids, isLoaded: true);
    } catch (e) {
      debugPrint('Wishlist fetch failed: $e');
      return const WishlistState(productIds: {}, isLoaded: true);
    }
  }

  /// Optimistic toggle using add/remove endpoints (not full list replace).
  Future<void> toggle(String productId) async {
    final current = state.valueOrNull ?? const WishlistState(productIds: {});
    final wasIn = current.contains(productId);
    final updatedIds = Set<String>.from(current.productIds);
    if (wasIn) {
      updatedIds.remove(productId);
    } else {
      updatedIds.add(productId);
    }
    state = AsyncValue.data(
      WishlistState(productIds: updatedIds, isLoaded: current.isLoaded),
    );

    final api = ref.read(apiServiceProvider);
    try {
      if (wasIn) {
        await api.removeWishlistItem(productId);
      } else {
        await api.addWishlistItem(productId);
      }
    } catch (e) {
      debugPrint('Wishlist sync failed: $e');
      state = AsyncValue.data(current);
    }
  }

  bool isWishlisted(String productId) {
    return (state.valueOrNull?.productIds ?? const {}).contains(productId);
  }
}

final wishlistProvider =
    AsyncNotifierProvider.autoDispose<WishlistNotifier, WishlistState>(
      WishlistNotifier.new,
    );
