import 'user_model.dart';
import 'post_model.dart';

class SocialActivity {
  final String id;
  final String type;
  final String description;
  final UserModel? user;
  final PostModel? post;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final bool isLoaded;

  String get kind => type;

  SocialActivity({
    String? id,
    String? type,
    String? description,
    this.user,
    this.post,
    this.metadata,
    this.createdAt,
    bool? isLoaded,
  })  : id = id ?? '',
        type = type ?? '',
        description = description ?? '',
        isLoaded = isLoaded ?? false;

  factory SocialActivity.fromJson(Map<String, dynamic> json) {
    return SocialActivity(
      id: json['id']?.toString(),
      type: json['type'] as String?,
      description: json['description'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      post: json['post'] != null
          ? PostModel.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'user': user?.toJson(),
        'post': post?.toJson(),
        'metadata': metadata,
        'createdAt': createdAt?.toIso8601String(),
        'isLoaded': isLoaded,
      };
}

class PredictionModel {
  final String id;
  final String trendId;
  final String productId;
  final String productName;
  final String category;
  final String title;
  final String description;
  final String reasoning;
  final String imageUrl;
  final double confidence;
  final double predictedTrendScore;
  final List<String> recommendedCategories;
  final List<Map<String, dynamic>> predictedProducts;
  final DateTime? predictedAt;
  final bool isLoaded;

  PredictionModel({
    String? id,
    String? trendId,
    String? productId,
    String? productName,
    String? category,
    String? title,
    String? description,
    String? reasoning,
    String? imageUrl,
    double? confidence,
    double? predictedTrendScore,
    List<String>? recommendedCategories,
    List<Map<String, dynamic>>? predictedProducts,
    this.predictedAt,
    bool? isLoaded,
  })  : id = id ?? '',
        trendId = trendId ?? '',
        productId = productId ?? '',
        productName = productName ?? '',
        category = category ?? '',
        title = title ?? '',
        description = description ?? '',
        reasoning = reasoning ?? '',
        imageUrl = imageUrl ?? '',
        confidence = confidence ?? 0.0,
        predictedTrendScore = predictedTrendScore ?? 0.0,
        recommendedCategories = recommendedCategories ?? const [],
        predictedProducts = predictedProducts ?? const [],
        isLoaded = isLoaded ?? false;

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      id: json['id']?.toString(),
      trendId: json['trendId'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      category: json['category'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      reasoning: json['reasoning'] as String?,
      imageUrl: json['imageUrl'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      predictedTrendScore: (json['predictedTrendScore'] as num?)?.toDouble(),
      recommendedCategories: (json['recommendedCategories'] as List<dynamic>?)?.cast<String>(),
      predictedProducts: (json['predictedProducts'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      predictedAt: json['predictedAt'] != null
          ? DateTime.parse(json['predictedAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trendId': trendId,
        'productId': productId,
        'productName': productName,
        'category': category,
        'title': title,
        'description': description,
        'reasoning': reasoning,
        'imageUrl': imageUrl,
        'confidence': confidence,
        'predictedTrendScore': predictedTrendScore,
        'recommendedCategories': recommendedCategories,
        'predictedProducts': predictedProducts,
        'predictedAt': predictedAt?.toIso8601String(),
        'isLoaded': isLoaded,
      };
}