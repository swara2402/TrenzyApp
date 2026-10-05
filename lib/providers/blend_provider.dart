import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blend_model.dart';

import '../services/api_service_base.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart';

final blendNotifierProvider =
    StateNotifierProvider<BlendNotifier, AsyncValue<void>>((ref) {
  return BlendNotifier(ref.watch(apiServiceProvider));
});

class BlendNotifier extends StateNotifier<AsyncValue<void>> {
  BlendNotifier(this._api) : super(const AsyncData(null));

  final ApiServiceBase _api;

  Future<Map<String, dynamic>?> createBlend({
    required String name,
    String? description,
    String? theme,
  }) async {
    state = const AsyncLoading();
    try {
      final newBlend = await _api.createBlend(
        name: name,
        description: description,
        theme: theme,
      );
      state = const AsyncData(null);
      return newBlend;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final blendGroupProvider = FutureProvider.autoDispose
    .family<BlendGroup, String>((ref, groupId) async {
      final uid = ref.watch(authProvider.select((a) => a.valueOrNull?.id));
      if (uid == null) return BlendGroup(id: groupId, name: '', inviteCode: '', members: const []);

      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendGroup(groupId);
      return BlendGroup.fromJson(data);
    });

final blendResultsProvider = FutureProvider.autoDispose
    .family<BlendResults, String>((ref, groupId) async {
      final uid = ref.watch(authProvider.select((a) => a.valueOrNull?.id));
      if (uid == null) return BlendResults(groupId: groupId, groupName: '', recommendations: const []);

      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendResults(groupId);
      return BlendResults.fromJson(data);
    });

final userBlendGroupsProvider = FutureProvider.autoDispose<List<BlendGroup>>((
  ref,
) async {
  final uid = ref.watch(authProvider.select((auth) => auth.valueOrNull?.id));
  if (uid == null) return const <BlendGroup>[];

  final api = ref.watch(apiServiceProvider);
  final groups = await api.getUserBlendGroups();
  return groups
      .map((e) {
        try {
          return BlendGroup.fromJson(Map<String, dynamic>.from(e as Map));
        } catch (_) {
          return null;
        }
      })
      .whereType<BlendGroup>()
      .toList();
});