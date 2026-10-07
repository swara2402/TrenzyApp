import 'product_model.dart';

class TrendModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final String productId;
  final String productName;
  final List<ProductModel> products;
  final int searchVolume;
  final double growth;
  final double trendingScore;
  final int viewCount;
  final int clickCount;
  final bool isHot;
  final DateTime createdAt;

  TrendModel({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? category,
    String? productId,
    String? productName,
    List<ProductModel>? products,
    int? searchVolume,
    double? growth,
    double? trendingScore,
    int? viewCount,
    int? clickCount,
    bool? isHot,
    DateTime? createdAt,
  })  : id = id ?? '',
        name = name ?? '',
        description = description ?? '',
        imageUrl = imageUrl ?? '',
        category = category ?? '',
        productId = productId ?? '',
        productName = productName ?? '',
        products = products ?? const [],
        searchVolume = searchVolume ?? 0,
        growth = growth ?? 0.0,
        trendingScore = trendingScore ?? 0.0,
        viewCount = viewCount ?? 0,
        clickCount = clickCount ?? 0,
        isHot = isHot ?? false,
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory TrendModel.fromJson(Map<String, dynamic> json) {
    return TrendModel(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      category: json['category'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      searchVolume: json['searchVolume'] as int?,
      growth: (json['growth'] as num?)?.toDouble(),
      trendingScore: (json['trendingScore'] as num?)?.toDouble(),
      viewCount: json['viewCount'] as int?,
      clickCount: json['clickCount'] as int?,
      isHot: json['isHot'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'productId': productId,
      'productName': productName,
      'products': products.map((item) => item.toJson()).toList(),
      'searchVolume': searchVolume,
      'growth': growth,
      'trendingScore': trendingScore,
      'viewCount': viewCount,
      'clickCount': clickCount,
      'isHot': isHot,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}