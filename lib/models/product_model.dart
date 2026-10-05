import 'trend_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String category;
  final String subcategory;
  final String brand;
  final String style;
  final String color;
  final String displayColor;
  final double score;
  final double effectivePrice;
  final double rating;
  final String reason;
  final String effectiveBrand;
  final String gender;
  final String season;
  final String occasion;
  final String fit;
  final String usage;
  final String outfitRole;
  final List<String> tags;

  ProductModel({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    String? category,
    String? subcategory,
    String? brand,
    String? style,
    String? color,
    String? displayColor,
    double? score,
    double? effectivePrice,
    double? rating,
    String? reason,
    String? effectiveBrand,
    String? gender,
    String? season,
    String? occasion,
    String? fit,
    String? usage,
    String? outfitRole,
    List<String>? tags,
  }) : id = id ?? '',
       name = name ?? '',
       description = description ?? '',
       imageUrl = imageUrl ?? '',
       price = price ?? 0.0,
       category = category ?? '',
       subcategory = subcategory ?? '',
       brand = brand ?? '',
       style = style ?? '',
       color = color ?? '',
       displayColor = displayColor ?? '',
       score = score ?? 0.0,
       effectivePrice = effectivePrice ?? (price ?? 0.0),
       rating = rating ?? 0.0,
       reason = reason ?? '',
       effectiveBrand = effectiveBrand ?? ((brand?.isEmpty ?? true) ? 'Unknown Brand' : (brand ?? 'Unknown Brand')),
       gender = gender ?? '',
       season = season ?? '',
       occasion = occasion ?? '',
       fit = fit ?? '',
       usage = usage ?? '',
       outfitRole = outfitRole ?? '',
       tags = tags ?? const [];

  factory ProductModel.fromTrendModel(TrendModel trend) {
    if (trend.products.isNotEmpty) {
      return trend.products.first;
    }
    return ProductModel(
      id: trend.productId,
      name: trend.productName,
      description: trend.description,
      imageUrl: trend.imageUrl,
      category: trend.category,
      reason: '+${(trend.growth * 100).toInt()}% search growth',
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      brand: json['brand'] as String?,
      style: json['style'] as String?,
      color: json['color'] as String?,
      displayColor: json['displayColor'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      effectivePrice: (json['effectivePrice'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      reason: json['reason'] as String?,
      effectiveBrand: json['effectiveBrand'] as String?,
      gender: json['gender'] as String?,
      season: json['season'] as String?,
      occasion: json['occasion'] as String?,
      fit: json['fit'] as String?,
      usage: json['usage'] as String?,
      outfitRole: json['outfitRole'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'price': price,
      'category': category,
      'subcategory': subcategory,
      'brand': brand,
      'style': style,
      'color': color,
      'displayColor': displayColor,
      'score': score,
      'effectivePrice': effectivePrice,
      'rating': rating,
      'reason': reason,
      'effectiveBrand': effectiveBrand,
      'gender': gender,
      'season': season,
      'occasion': occasion,
      'fit': fit,
      'usage': usage,
      'outfitRole': outfitRole,
      'tags': tags,
    };
  }
}