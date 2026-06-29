import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/blend_model.dart';
import 'auth_provider.dart';

final blendGroupProvider = FutureProvider.autoDispose
    .family<BlendGroup, String>((ref, groupId) async {
      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendGroup(groupId);
      return BlendGroup.fromJson(data);
    });

final blendResultsProvider = FutureProvider.autoDispose
    .family<BlendResults, String>((ref, groupId) async {
      final api = ref.watch(apiServiceProvider);
      final data = await api.getBlendResults(groupId);
      return BlendResults.fromJson(data);
    });

final userBlendGroupsProvider = FutureProvider.autoDispose<List<BlendGroup>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final user = auth.value;

  if (user == null) return const <BlendGroup>[];

  final api = ref.watch(apiServiceProvider);
  final groups = await api.getUserBlendGroups();
  return groups
      .map((e) => BlendGroup.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});
