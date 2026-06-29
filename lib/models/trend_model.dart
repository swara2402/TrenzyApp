/// ============================================================
/// TREND MODEL - Trend Prediction Data
/// ============================================================
library;

class TrendModel {
  const TrendModel({
    required this.productId,
    required this.productName,
    this.category,
    this.imageUrl,
    required this.viewCount,
    required this.clickCount,
    required this.trendingScore,
    required this.momentum,
    required this.timeframe,
  });

  final String productId;
  final String productName;
  final String? category;
  final String? imageUrl;
  final int viewCount;
  final int clickCount;
  final double trendingScore;
  final double momentum;
  final String timeframe;

  factory TrendModel.fromJson(Map<String, dynamic> json) {
    return TrendModel(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      category: json['category']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
      trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0.0,
      momentum: (json['momentum'] as num?)?.toDouble() ?? 0.0,
      timeframe: json['timeframe']?.toString() ?? 'daily',
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'category': category,
    'imageUrl': imageUrl,
    'viewCount': viewCount,
    'clickCount': clickCount,
    'trendingScore': trendingScore,
    'momentum': momentum,
    'timeframe': timeframe,
  };
}

class PredictionModel {
  const PredictionModel({
    required this.productId,
    required this.productName,
    this.category,
    this.imageUrl,
    required this.predictedTrendScore,
    required this.confidence,
    required this.reasoning,
  });

  final String productId;
  final String productName;
  final String? category;
  final String? imageUrl;
  final double predictedTrendScore;
  final double confidence;
  final String reasoning;

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      category: json['category']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      predictedTrendScore:
          (json['predictedTrendScore'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'category': category,
    'imageUrl': imageUrl,
    'predictedTrendScore': predictedTrendScore,
    'confidence': confidence,
    'reasoning': reasoning,
  };
}
