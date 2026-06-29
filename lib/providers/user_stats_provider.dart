import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class UserStats {
  const UserStats({
    this.decisionCount = 0,
    this.friendsCount = 0,
    this.matchPercentage,
    this.voteCount,
    this.styleAesthetic,
  });

  final int decisionCount;
  final int friendsCount;
  final int? matchPercentage;
  final int? voteCount;
  final String? styleAesthetic;

  UserStats copyWith({
    int? decisionCount,
    int? friendsCount,
    int? matchPercentage,
    int? voteCount,
    String? styleAesthetic,
  }) {
    return UserStats(
      decisionCount: decisionCount ?? this.decisionCount,
      friendsCount: friendsCount ?? this.friendsCount,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      voteCount: voteCount ?? this.voteCount,
      styleAesthetic: styleAesthetic ?? this.styleAesthetic,
    );
  }
}

final userStatsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (user == null) return const UserStats();

  final api = ref.watch(apiServiceProvider);

  int decisionCount = 0;
  int friendsCount = 0;
  int? matchPercentage;
  int? voteCount;
  String? styleAesthetic;

  try {
    final decisions = await api.getDecisions();
    decisionCount = decisions.length;
  } catch (_) {
    // Keep default 0
  }

  try {
    final friends = await api.getFriends();
    friendsCount = friends.length;
  } catch (_) {
    // Keep default 0
  }

  return UserStats(
    decisionCount: decisionCount,
    friendsCount: friendsCount,
    matchPercentage: matchPercentage,
    voteCount: voteCount,
    styleAesthetic: styleAesthetic,
  );
});
