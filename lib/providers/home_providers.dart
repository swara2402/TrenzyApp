import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../models/wardrobe_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;
import 'discover_providers.dart';
import 'wardrobe_provider.dart';

final todaysAiPicksProvider =
    FutureProvider.autoDispose<List<RecommendedProduct>>((ref) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return [];

      final api = ref.watch(apiServiceProvider);
      try {
        // Do not leave the Home feed showing skeleton cards indefinitely when
        // the recommendations endpoint is slow or the staging service is cold.
        final res = await api
            .getRecommendedProducts(limit: 8)
            .timeout(const Duration(seconds: 12));
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
        // _AiPicksSection renders its empty-state CTA on failure, so users
        // can continue to Discover instead of being stuck on blank cards.
        return [];
      }
    });

final aiOutfitMatchesProvider = FutureProvider.autoDispose<List<OutfitIdea>>((
  ref,
) async {
  final recs = await ref.watch(wardrobeRecommendationsProvider.future);
  return recs?.outfitIdeas ?? const <OutfitIdea>[];
});
