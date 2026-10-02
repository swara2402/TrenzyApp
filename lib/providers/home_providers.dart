import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../models/wardrobe_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;
import 'discover_providers.dart';
import 'wardrobe_provider.dart';

final todaysAiPicksProvider =
    FutureProvider.autoDispose<List<RecommendedProduct>>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return [];

  final api = ref.watch(apiServiceProvider);
  try {
    final res = await api.getRecommendedProducts(limit: 8);
    final items = res['products'] as List<dynamic>? ?? [];
    return items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final data = Map<String, dynamic>.from(map['data'] as Map? ?? map);
      return RecommendedProduct(
        product: ProductModel.fromJson(data),
        reason: map['reason']?.toString() ?? '',
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

final aiOutfitMatchesProvider =
    FutureProvider.autoDispose<List<OutfitIdea>>((ref) async {
  final recs = await ref.watch(wardrobeRecommendationsProvider.future);
  return recs?.outfitIdeas ?? const <OutfitIdea>[];
});
