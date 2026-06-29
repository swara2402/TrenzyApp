// lib/models/product_model.dart

/// ============================================================
/// PRODUCT MODEL - SINGLE SOURCE OF TRUTH
/// ============================================================
library;

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    this.subcategory,
    this.articleType,
    this.gender,
    this.color,
    this.season,
    this.usage,
    this.price,
    this.rating,
    this.imageUrl,
    this.affiliateLinks,
    this.tags,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? subcategory;
  final String? articleType;
  final String? gender;
  final String? color;
  final String? season;
  final String? usage;
  final double? price;
  final double? rating;
  final String? imageUrl;
  final String? affiliateLinks;
  final List<String>? tags;

  // Keep comments minimal and meaningful
  String get formattedPrice => '₹${(price ?? 0).toStringAsFixed(0)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'subcategory': subcategory,
    'article_type': articleType,
    'gender': gender,
    'color': color,
    'season': season,
    'usage': usage,
    'price': price,
    'rating': rating,
    'image_url': imageUrl,
    'affiliate_links': affiliateLinks,
    'tags': tags,
  };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString(),
      category: json['category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      articleType: json['article_type']?.toString(),
      gender: json['gender']?.toString(),
      color: json['color']?.toString(),
      season: json['season']?.toString(),
      usage: json['usage']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: json['image_url']?.toString(),
      affiliateLinks: json['affiliate_links']?.toString(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

/// ============================================================
/// SEARCH PARAMS
/// ============================================================

class ProductSearchParams {
  const ProductSearchParams({
    this.query = '',
    this.category,
    this.minPrice,
    this.maxPrice,
    this.sort = 'relevance',
  });

  final String query;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final String sort;

  @override
  bool operator ==(Object other) {
    return other is ProductSearchParams &&
        other.query == query &&
        other.category == category &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(query, category, minPrice, maxPrice, sort);
}
