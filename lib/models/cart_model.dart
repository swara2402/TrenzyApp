import 'product_model.dart';

class CartItem {
  final int id;
  final String? cartId;
  final ProductModel product;
  final int quantity;
  final DateTime? addedAt;
  final bool? isLoaded;

  CartItem({
    this.id = -1,
    this.cartId,
    required this.product,
    this.quantity = 1,
    this.addedAt,
    this.isLoaded,
  });

  double get totalPrice {
    return product.effectivePrice * quantity;
  }

  CartItem copyWith({
    int? id,
    String? cartId,
    ProductModel? product,
    int? quantity,
    DateTime? addedAt,
    bool? isLoaded,
  }) {
    return CartItem(
      id: id ?? this.id,
      cartId: cartId ?? this.cartId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedId = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? -1;

    final rawProduct = json['product'];
    final product = rawProduct != null
        ? ProductModel.fromJson(rawProduct as Map<String, dynamic>)
        : ProductModel(
            id: json['productId'] as String?,
            name: json['productName'] as String?,
            imageUrl: json['productImage'] as String?,
            price: (json['productPrice'] as num?)?.toDouble(),
          );

    return CartItem(
      id: parsedId,
      cartId: json['cartId'] as String?,
      product: product,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cartId': cartId,
      'product': product.toJson(),
      'quantity': quantity,
      'addedAt': addedAt?.toIso8601String(),
      'isLoaded': isLoaded,
    };
  }
}

class CartState {
  final List<CartItem> items;
  final double? total;
  final int? cartId;
  final bool isLoaded;

  const CartState({
    this.items = const [],
    this.total,
    this.cartId,
    this.isLoaded = false,
  });

  int get totalItems {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  CartState copyWith({
    List<CartItem>? items,
    double? total,
    int? cartId,
    bool? isLoaded,
  }) {
    return CartState(
      items: items ?? this.items,
      total: total ?? this.total,
      cartId: cartId ?? this.cartId,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  factory CartState.fromJson(Map<String, dynamic> json) {
    return CartState(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toDouble(),
      isLoaded: (json['isLoaded'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'cartId': cartId,
      'isLoaded': isLoaded,
    };
  }
}