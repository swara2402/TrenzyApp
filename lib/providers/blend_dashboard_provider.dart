import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blend_dashboard_models.dart';
import '../services/api_service_base.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

final blendDashboardProvider = FutureProvider.autoDispose
    .family<BlendDashboard, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) {
        return BlendDashboard(id: blendId, name: '', memberCount: 0);
      }

      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendDashboard(blendId);
      return BlendDashboard.fromJson(data);
    });

final sharedWishlistProvider = FutureProvider.autoDispose
    .family<List<SharedWishlistItem>, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <SharedWishlistItem>[];

      final api = ref.watch(apiServiceProvider);
      final data = await api.getSharedWishlist(blendId);
      return data
          .map(
            (e) => SharedWishlistItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    });

final moodboardProvider = FutureProvider.autoDispose
    .family<List<MoodboardItem>, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <MoodboardItem>[];

      final api = ref.watch(apiServiceProvider);
      final data = await api.getMoodboard(blendId);
      return data
          .map(
            (e) => MoodboardItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

final blendInsightsProvider = FutureProvider.autoDispose
    .family<List<BlendInsight>, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <BlendInsight>[];

      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendInsights(blendId);
      return data
          .map(
            (e) => BlendInsight.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

final blendActivityProvider = FutureProvider.autoDispose
    .family<List<ActivityEvent>, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <ActivityEvent>[];

      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendActivity(blendId);
      final events = data['events'] as List<dynamic>? ?? [];
      return events
          .map(
            (e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });

final blendSettingsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, blendId) async {
      final uid = ref.watch(
        auth_p.authProvider.select((a) => a.valueOrNull?.id),
      );
      if (uid == null) return const <String, dynamic>{};

      final api = ref.watch(apiServiceProvider);
      return await api.getBlendSettings(blendId);
    });

class BlendWishlistNotifier extends StateNotifier<AsyncValue<void>> {
  BlendWishlistNotifier(this._api) : super(const AsyncData(null));

  final ApiServiceBase _api;

  Future<bool> addItem({
    required String blendId,
    required String productId,
    String productName = '',
    double? productPrice,
    String? productImage,
    String? productBrand,
    String? productCategory,
    String? productUrl,
    String? notes,
  }) async {
    try {
      await _api.addToSharedWishlist(
        blendId,
        productId: productId,
        productName: productName,
        productPrice: productPrice,
        productImage: productImage,
        productBrand: productBrand,
        productCategory: productCategory,
        productUrl: productUrl,
        notes: notes,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateItem({
    required String blendId,
    required int itemId,
    String? notes,
    bool? isFavorite,
    String? purchaseLink,
  }) async {
    try {
      await _api.updateWishlistItem(
        blendId,
        itemId,
        notes: notes,
        isFavorite: isFavorite,
        purchaseLink: purchaseLink,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeItem({
    required String blendId,
    required int itemId,
  }) async {
    try {
      await _api.removeFromSharedWishlist(blendId, itemId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final blendWishlistNotifierProvider =
    StateNotifierProvider<BlendWishlistNotifier, AsyncValue<void>>((ref) {
      return BlendWishlistNotifier(ref.watch(apiServiceProvider));
    });

class BlendInsightNotifier extends StateNotifier<AsyncValue<void>> {
  BlendInsightNotifier(this._api) : super(const AsyncData(null));

  final ApiServiceBase _api;

  Future<int?> refresh({required String blendId}) async {
    try {
      final result = await _api.refreshBlendInsights(blendId);
      return result['count'] as int?;
    } catch (e) {
      return null;
    }
  }
}

final blendInsightNotifierProvider =
    StateNotifierProvider<BlendInsightNotifier, AsyncValue<void>>((ref) {
      return BlendInsightNotifier(ref.watch(apiServiceProvider));
    });

class MoodboardNotifier extends StateNotifier<AsyncValue<void>> {
  MoodboardNotifier(this._api) : super(const AsyncData(null));

  final ApiServiceBase _api;

  Future<bool> addItem({
    required String blendId,
    required String itemType,
    Map<String, dynamic>? content,
    String? imageUrl,
    String? caption,
  }) async {
    try {
      await _api.addToMoodboard(
        blendId,
        itemType: itemType,
        content: content,
        imageUrl: imageUrl,
        caption: caption,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeItem({
    required String blendId,
    required int itemId,
  }) async {
    try {
      await _api.removeFromMoodboard(blendId, itemId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final moodboardNotifierProvider =
    StateNotifierProvider<MoodboardNotifier, AsyncValue<void>>((ref) {
      return MoodboardNotifier(ref.watch(apiServiceProvider));
    });
