import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wardrobe_model.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

class WardrobeState {
  final List<WardrobeItem> items;
  final int offset;
  final int limit;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  const WardrobeState({
    this.items = const [],
    this.offset = 0,
    this.limit = 50,
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  WardrobeState copyWith({
    List<WardrobeItem>? items,
    int? offset,
    int? limit,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return WardrobeState(
      items: items ?? this.items,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class WardrobeNotifier extends AutoDisposeAsyncNotifier<WardrobeState> {
  @override
  Future<WardrobeState> build() async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
    if (uid == null) return const WardrobeState();

    final api = ref.read(apiServiceProvider);
    final res = await api.getWardrobe(offset: 0, limit: 50);
    final rawList = res['wardrobe'] as List<dynamic>? ?? [];
    final pagination = res['pagination'] as Map<String, dynamic>? ?? {};

    final items = rawList.map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>)).toList();
    final total = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : items.length;
    final hasMore = pagination['hasMore'] == true || (items.length < total);

    return WardrobeState(
      items: items,
      offset: 0,
      limit: 50,
      total: total,
      hasMore: hasMore,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null || !currentState.hasMore || currentState.isLoadingMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final api = ref.read(apiServiceProvider);
      final nextOffset = currentState.items.length;
      final res = await api.getWardrobe(offset: nextOffset, limit: 50);
      final rawList = res['wardrobe'] as List<dynamic>? ?? [];
      final pagination = res['pagination'] as Map<String, dynamic>? ?? {};

      final newItems = rawList.map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>)).toList();
      final updatedItems = [...currentState.items, ...newItems];
      final total = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : updatedItems.length;
      final hasMore = pagination['hasMore'] == true || (updatedItems.length < total);

      state = AsyncData(currentState.copyWith(
        items: updatedItems,
        offset: nextOffset,
        total: total,
        hasMore: hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  // ── Mutations: optimistic UI with rollback on API failure ───────────────

  /// Adds an item via the API, then refreshes so the server-assigned id,
  /// created_at and ordering are reflected.
  Future<void> addItem({
    required String name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
  }) async {
    final api = ref.read(apiServiceProvider);
    await api.addWardrobeItem(
      name: name,
      imageUrl: imageUrl,
      category: category,
      color: color,
      season: season,
      brand: brand,
    );
    await refresh();
  }

  /// Optimistically patches [itemId] locally; rolls back on failure.
  Future<void> updateItem(
    int itemId, {
    String? name,
    String? imageUrl,
    String? category,
    String? color,
    String? season,
    String? brand,
    bool? isFavorite,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;
    final previousItems = currentState.items;

    state = AsyncData(currentState.copyWith(items: [
      for (final item in currentState.items)
        if (int.tryParse(item.id) == itemId)
          WardrobeItem(
            id: item.id,
            userId: item.userId,
            name: name ?? item.name,
            category: category ?? item.category,
            color: color ?? item.color,
            addedAt: item.addedAt,
            imageUrl: imageUrl ?? item.imageUrl,
            brand: brand ?? item.brand,
            isFavorite: isFavorite ?? item.isFavorite,
            season: season ?? item.season,
          )
        else
          item,
    ]));

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateWardrobeItem(
        itemId,
        name: name,
        imageUrl: imageUrl,
        category: category,
        color: color,
        season: season,
        brand: brand,
        isFavorite: isFavorite,
      );
    } catch (_) {
      // Rollback to the pre-mutation list.
      state = AsyncData(currentState.copyWith(items: previousItems));
      rethrow;
    }
  }

  /// Optimistically removes [itemId]; restores it on failure.
  Future<void> deleteItem(int itemId) async {
    final currentState = state.value;
    if (currentState == null) return;
    final previousItems = currentState.items;

    state = AsyncData(currentState.copyWith(
      items: previousItems.where((i) => int.tryParse(i.id) != itemId).toList(),
      total: previousItems.length - 1 > 0 ? currentState.total - 1 : 0,
    ));

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteWardrobeItem(itemId);
    } catch (_) {
      state = AsyncData(currentState.copyWith(items: previousItems));
      rethrow;
    }
  }
}

final wardrobeProvider = AsyncNotifierProvider.autoDispose<WardrobeNotifier, WardrobeState>(() {
  return WardrobeNotifier();
});

final filteredWardrobeProvider = FutureProvider.autoDispose.family<List<WardrobeItem>, Map<String, String?>>((ref, filters) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <WardrobeItem>[];

  final api = ref.read(apiServiceProvider);
  final res = await api.getWardrobe(
    category: filters['category'],
    color: filters['color'],
    season: filters['season'],
    brand: filters['brand'],
    favoriteOnly: filters['favoriteOnly'] == 'true',
    search: filters['search'],
  );
  final rawList = res['wardrobe'] as List<dynamic>? ?? [];
  return rawList.map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>)).toList();
});

class OutfitsNotifier extends AutoDisposeAsyncNotifier<List<Outfit>> {
  @override
  Future<List<Outfit>> build() async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
    if (uid == null) return const <Outfit>[];

    final api = ref.read(apiServiceProvider);
    final data = await api.getOutfits();
    final outfitsList = data['outfits'] as List<dynamic>? ?? [];
    return outfitsList.map((e) => Outfit.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates an outfit with real wardrobe item ids; refreshes from the API
  /// so server state (ids, ordering) is authoritative. Rolls back on failure.
  Future<void> createOutfit({
    required String name,
    required List<int> wardrobeItemIds,
    String? occasion,
  }) async {
    if (wardrobeItemIds.isEmpty) {
      throw ArgumentError('createOutfit requires at least one wardrobe item id');
    }
    final previous = state.valueOrNull ?? const <Outfit>[];
    try {
      final api = ref.read(apiServiceProvider);
      await api.createOutfit(
        name: name,
        wardrobeItemIds: wardrobeItemIds,
        occasion: occasion,
      );
      ref.invalidateSelf();
      ref.invalidate(wardrobeRecommendationsProvider);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically updates an outfit; rolls back on failure.
  Future<void> updateOutfit(
    int outfitId, {
    String? name,
    String? occasion,
    List<int>? wardrobeItemIds,
  }) async {
    final previous = state.valueOrNull ?? const <Outfit>[];
    state = AsyncData([
      for (final o in previous)
        if (int.tryParse(o.id) == outfitId)
          Outfit(
            id: o.id,
            userId: o.userId,
            name: name ?? o.name,
            description: o.description,
            items: o.items,
            wardrobeItemIds: wardrobeItemIds ?? o.wardrobeItemIds,
            occasion: occasion ?? o.occasion,
            isFavorite: o.isFavorite,
            createdAt: o.createdAt,
          )
        else
          o,
    ]);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateOutfit(
        outfitId,
        name: name,
        occasion: occasion,
        wardrobeItemIds: wardrobeItemIds,
      );
      ref.invalidate(wardrobeRecommendationsProvider);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically deletes an outfit; restores on failure.
  Future<void> deleteOutfit(int outfitId) async {
    final previous = state.valueOrNull ?? const <Outfit>[];
    state = AsyncData(previous.where((o) => int.tryParse(o.id) != outfitId).toList());
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteOutfit(outfitId);
      ref.invalidate(wardrobeRecommendationsProvider);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final outfitsProvider =
    AsyncNotifierProvider.autoDispose<OutfitsNotifier, List<Outfit>>(() {
  return OutfitsNotifier();
});

final wardrobeRecommendationsProvider = FutureProvider.autoDispose<WardrobeRecommendationsResponse?>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return null;

  final api = ref.read(apiServiceProvider);
  final data = await api.getWardrobeRecommendations(limit: 5);
  return WardrobeRecommendationsResponse.fromJson(data);
});

final personaProvider = FutureProvider.autoDispose<StylePersona?>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return null;

  final api = ref.read(apiServiceProvider);
  final data = await api.getPersona();
  if (data == null) return null;
  return StylePersona.fromJson(data);
});