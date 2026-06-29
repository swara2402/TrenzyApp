// lib/models/social_room_state.dart

import 'product_model.dart';
import 'decision_flow.dart';

/// Social Room State - Single source of truth
class SocialRoomState {
  const SocialRoomState({
    required this.options,
    required this.voteCounts,
    this.reactions = const [],
    this.participantCount = 1,
    this.lastVotedOptionId,
  });

  final List<ProductModel> options; // ✅ Uses ProductModel
  final Map<String, int> voteCounts;
  final List<SocialReaction> reactions;
  final int participantCount;
  final String? lastVotedOptionId;

  /// Create empty state with options
  factory SocialRoomState.empty(List<ProductModel> options) {
    return SocialRoomState(
      options: options,
      voteCounts: {for (final option in options) option.id: 0},
    );
  }

  /// Create from JSON
  factory SocialRoomState.fromJson(
    Map<String, dynamic> json,
    List<ProductModel> fallbackOptions,
  ) {
    // Backend currently sends voteCounts/reactions but not full product options.
    // Keep using the locally provided fallbackOptions to avoid missing/incorrect image URLs.
    final options = fallbackOptions;

    final voteCountsRaw = json['voteCounts'] as Map<String, dynamic>? ?? {};
    final voteCounts = voteCountsRaw.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    final reactionsRaw = json['reactions'] as List<dynamic>? ?? [];
    final reactions = reactionsRaw
        .map((e) => SocialReaction.fromJson(e as Map<String, dynamic>))
        .toList();

    return SocialRoomState(
      options: options,
      voteCounts: voteCounts,
      reactions: reactions,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 1,
      lastVotedOptionId: json['lastVotedOptionId']?.toString(),
    );
  }

  /// Copy with updates
  SocialRoomState copyWith({
    List<ProductModel>? options,
    Map<String, int>? voteCounts,
    List<SocialReaction>? reactions,
    int? participantCount,
    String? lastVotedOptionId,
  }) {
    return SocialRoomState(
      options: options ?? this.options,
      voteCounts: voteCounts ?? this.voteCounts,
      reactions: reactions ?? this.reactions,
      participantCount: participantCount ?? this.participantCount,
      lastVotedOptionId: lastVotedOptionId ?? this.lastVotedOptionId,
    );
  }

  /// Get winner (most voted option)
  ProductModel? get winner {
    if (options.isEmpty) return null;
    return options.reduce((a, b) {
      final aVotes = voteCounts[a.id] ?? 0;
      final bVotes = voteCounts[b.id] ?? 0;
      return aVotes >= bVotes ? a : b;
    });
  }

  /// Get total votes
  int get totalVotes => voteCounts.values.fold(0, (sum, v) => sum + v);

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'options': options.map((e) => e.toJson()).toList(),
    'voteCounts': voteCounts,
    'reactions': reactions.map((e) => e.toJson()).toList(),
    'participantCount': participantCount,
    'lastVotedOptionId': lastVotedOptionId,
  };
}
