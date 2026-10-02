import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

class FriendsState {
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.suggestions = const [],
    this.isLoaded = false,
  });

  final List<Friend> friends;
  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;
  final List<FriendSuggestion> suggestions;
  final bool isLoaded;

  int get friendCount => friends.length;
  int get pendingCount => incoming.length;

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequestItem>? incoming,
    List<FriendRequestItem>? outgoing,
    List<FriendSuggestion>? suggestions,
    bool? isLoaded,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      suggestions: suggestions ?? this.suggestions,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class FriendsNotifier extends AutoDisposeAsyncNotifier<FriendsState> {
  @override
  Future<FriendsState> build() async {
    final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
    if (uid == null) {
      return const FriendsState(isLoaded: true);
    }

    return _fetch();
  }

  Future<FriendsState> _fetch() async {
    final api = ref.read(apiServiceProvider);
    try {
      final friends = await api.getFriends();
      final incomingRaw = await api.getFriendRequests(box: 'incoming');
      final outgoingRaw = await api.getFriendRequests(box: 'outgoing');
      List<FriendSuggestion> suggestions = const [];
      try {
        suggestions = await api.getFriendSuggestions();
      } catch (e) {
        debugPrint('Friend suggestions failed: $e');
      }
      return FriendsState(
        friends: friends,
        incoming: incomingRaw
            .whereType<Map>()
            .map((e) => FriendRequestItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        outgoing: outgoingRaw
            .whereType<Map>()
            .map((e) => FriendRequestItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        suggestions: suggestions,
        isLoaded: true,
      );
    } catch (e) {
      debugPrint('Friends fetch failed: $e');
      return const FriendsState(isLoaded: true);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }

  Future<void> sendRequest(String toFirebaseUid) async {
    final current = state.valueOrNull ?? const FriendsState(isLoaded: true);
    state = AsyncData(
      current.copyWith(
        outgoing: [
          ...current.outgoing,
          FriendRequestItem(
            id: -1,
            fromFirebaseUid: '',
            fromName: 'You',
            toFirebaseUid: toFirebaseUid,
          ),
        ],
      ),
    );
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendFriendRequest(toFirebaseUid: toFirebaseUid);
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('sendRequest failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> accept(int requestId) async {
    final current = state.valueOrNull ?? const FriendsState(isLoaded: true);
    state = AsyncData(
      current.copyWith(
        incoming: current.incoming.where((r) => r.id != requestId).toList(),
      ),
    );
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptFriendRequest(requestId);
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('accept failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> reject(int requestId) async {
    final current = state.valueOrNull ?? const FriendsState(isLoaded: true);
    state = AsyncData(
      current.copyWith(
        incoming: current.incoming.where((r) => r.id != requestId).toList(),
      ),
    );
    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectFriendRequest(requestId);
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('reject failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> remove(int friendId) async {
    final current = state.valueOrNull ?? const FriendsState(isLoaded: true);
    state = AsyncData(
      current.copyWith(
        friends: current.friends.where((f) => f.id != friendId).toList(),
      ),
    );
    try {
      final api = ref.read(apiServiceProvider);
      await api.removeFriend(friendId);
      state = AsyncData(await _fetch());
    } catch (e) {
      debugPrint('remove friend failed: $e');
      state = AsyncData(current);
      rethrow;
    }
  }
}

final friendsProvider =
    AsyncNotifierProvider.autoDispose<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);

/// Back-compat alias used on logout invalidation.
final friendProvider = friendsProvider;
