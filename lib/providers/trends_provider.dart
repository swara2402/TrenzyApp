import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trend_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

/// Trending products provider.
///
/// Fetches trending products from the backend trend engine.
final trendingProductsProvider = FutureProvider.autoDispose
    .family<List<TrendModel>, TrendingParams>((ref, params) async {
      final auth = ref.watch(auth_p.authProvider);

      // Auth is still resolving — return empty list so UI shows loading skeleton.
      if (auth.isLoading) return const <TrendModel>[];

      // Not signed in — return empty list quietly.
      final user = auth.value;
      if (user == null) return const <TrendModel>[];

      final api = ref.watch(apiServiceProvider);
      final trends = await api.getTrendingProducts(
        category: params.category,
        timeframe: params.timeframe,
        limit: params.limit,
      );
      return trends
          .map((e) => TrendModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });

/// Prediction provider for AI-driven trend predictions.
final trendPredictionsProvider = FutureProvider.autoDispose
    .family<List<PredictionModel>, PredictionParams>((ref, params) async {
      final auth = ref.watch(auth_p.authProvider);

      if (auth.isLoading) return const <PredictionModel>[];

      final user = auth.value;
      if (user == null) return const <PredictionModel>[];

      final api = ref.watch(apiServiceProvider);
      final predictions = await api.getTrendPredictions(
        category: params.category,
        limit: params.limit,
      );
      return predictions
          .map(
            (e) =>
                PredictionModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

// Parameter classes for the providers
class TrendingParams {
  const TrendingParams({
    this.category,
    this.timeframe = 'daily',
    this.limit = 20,
  });

  final String? category;
  final String timeframe;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendingParams &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          timeframe == other.timeframe &&
          limit == other.limit;

  @override
  int get hashCode => category.hashCode ^ timeframe.hashCode ^ limit.hashCode;
}

class PredictionParams {
  const PredictionParams({this.category, this.limit = 10});

  final String? category;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PredictionParams &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          limit == other.limit;

  @override
  int get hashCode => category.hashCode ^ limit.hashCode;
}
