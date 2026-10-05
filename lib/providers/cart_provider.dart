// ignore_for_file: unchecked_use_of_nullable_value

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_model.dart';
import '../models/product_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

/// Server-backed cart. Loads from GET /api/cart when authenticated.
/// Mutations are optimistic with rollback on API failure.
class CartNotifier extends AutoDisposeAsyncNotifier<CartState> {
  @override
  Future<CartState> build() async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
    if (uid == null) {
      return const CartState(isLoaded: true);
    }

    return _fetch();
  }

  Future<CartState> _fetch() async {
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.getCart();
      return _parse(res);
    } catch (e) {
      debugPrint('Cart fetch failed: $e');
      return const CartState(isLoaded: true);
    }
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  CartState _parse(Map<String, dynamic> res) {
    final rawItems = res['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final cartRaw = res['cart'];
    int? cartId;
    if (cartRaw is Map && cartRaw['id'] != null) {
      cartId = (cartRaw['id'] is num)
          ? (cartRaw['id'] as num).toInt()
          : int.tryParse(cartRaw['id'].toString());
    }

    final double? parsedTotal = _toDoubleOrNull(res['total']);
    final double total = parsedTotal ??
        items.fold(0.0, (s, i) => s + i.totalPrice);

    return CartState(
      items: items,
      total: total,
      cartId: cartId,
      isLoaded: true,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }

  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    final current = state.valueOrNull ?? const CartState(isLoaded: true);
    final existingIndex =
        current.items.indexWhere((i) => i.product.id == product.id);

    final List<CartItem> optimistic;
    if (existingIndex >= 0) {
      optimistic = current.items.map((item) {
        if (item.product.id == product.id) {
          return item.copyWith(quantity: item.quantity + quantity);
        }
        return item;
      }).toList();
    } else {
      optimistic = [
        ...current.items,
        CartItem(id: -1, product: product, quantity: quantity),
      ];
    }
    state = AsyncData(
      current.copyWith(
        items: optimistic,
        total: optimistic.fold<double>(0.0, (s, i) => s + i.totalPrice),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      await api.addCartItem(productId: product.id, quantity: quantity);
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('addToCart failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  CartItem? _findByProduct(String? productId) {
    if (productId == null) return null;
    final current = state.valueOrNull;
    if (current == null) return null;
    for (final i in current.items) {
      if (i.product.id == productId) return i;
    }
    return null;
  }

  Future<void> incrementQuantity(String? productId) async {
    if (productId == null) return;
    final item = _findByProduct(productId);
    if (item == null) return;
    await updateQuantity(item.id, item.quantity + 1, productId: productId);
  }

  Future<void> decrementQuantity(String? productId) async {
    if (productId == null) return;
    final item = _findByProduct(productId);
    if (item == null) return;
    final currentQuantity = item.quantity;
    if (currentQuantity <= 1) {
      await removeCartLine(item.id, productId: productId);
      return;
    }
    await updateQuantity(item.id, item.quantity - 1, productId: productId);
  }

  Future<void> updateQuantity(
    int itemId,
    int quantity, {
    String? productId,
  }) async {
    if (quantity < 1) return;
    final current = state.valueOrNull ?? const CartState(isLoaded: true);

    final optimistic = [
      for (final i in current.items)
        if ((itemId > 0 && i.id == itemId) ||
            (productId != null && i.product.id == productId))
          i.copyWith(quantity: quantity)
        else
          i,
    ];
    state = AsyncData(
      current.copyWith(
        items: optimistic,
        total: optimistic.fold<double>(0.0, (s, i) => s + i.totalPrice),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      if (productId != null && productId.isNotEmpty) {
        await api.updateCartItem(productId: productId, quantity: quantity);
      }
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('updateQuantity failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> removeCartLine(int itemId, {String? productId}) async {
    final current = state.valueOrNull ?? const CartState(isLoaded: true);
    final optimistic = current.items
        .where(
          (i) => !(i.id == itemId ||
              (productId != null && i.product.id == productId)),
        )
        .toList();
    state = AsyncData(
      current.copyWith(
        items: optimistic,
        total: optimistic.fold<double>(0.0, (s, i) => s + i.totalPrice),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      if (productId != null && productId.isNotEmpty) {
        await api.removeCartItem(productId);
      }
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('removeCartLine failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> removeFromCart(ProductModel product) async {
    final item = _findByProduct(product.id);
    if (item == null) return;
    await removeCartLine(item.id, productId: product.id);
  }

  Future<void> clearCart() async {
    final current = state.valueOrNull ?? const CartState(isLoaded: true);
    state = AsyncData(const CartState(isLoaded: true));

    try {
      final api = ref.read(apiServiceProvider);
      await api.clearCart();
    } catch (e) {
      debugPrint('clearCart failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }
}

final cartProvider =
    AsyncNotifierProvider.autoDispose<CartNotifier, CartState>(CartNotifier.new);

final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).valueOrNull?.items ?? const [];
});

final cartTotalItemsProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).valueOrNull?.totalItems ?? 0;
});

final cartSubtotalProvider = Provider<double>((ref) {
  final s = ref.watch(cartProvider).valueOrNull;
  if (s == null) return 0;
  return (s.total > 0 ? s.total : s.subtotal) ?? 0.0;
});