import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

class FollowUserData {
  final String firebaseUid;
  final String? name;
  final String? avatarUrl;
  final String? createdAt;

  const FollowUserData({
    required this.firebaseUid,
    this.name,
    this.avatarUrl,
    this.createdAt,
  });

  factory FollowUserData.fromJson(Map<String, dynamic> json) {
    return FollowUserData(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

final followStatusProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, targetUid) async {
  final currentUid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (currentUid == null || currentUid == targetUid) return false;
  final api = ref.watch(apiServiceProvider);
  return api.getFollowStatus(targetUid);
});

final followersProvider =
    FutureProvider.autoDispose<List<FollowUserData>>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <FollowUserData>[];

  final api = ref.watch(apiServiceProvider);
  final data = await api.getFollowers();
  final list = (data['followers'] as List?)
          ?.map((e) => FollowUserData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      [];
  return list;
});

final followingProvider =
    FutureProvider.autoDispose<List<FollowUserData>>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <FollowUserData>[];

  final api = ref.watch(apiServiceProvider);
  final data = await api.getFollowing();
  final list = (data['following'] as List?)
          ?.map((e) => FollowUserData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      [];
  return list;
});
