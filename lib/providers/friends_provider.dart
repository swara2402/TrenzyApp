import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class FriendState {
  const FriendState({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
  });

  final List<dynamic> friends;
  final List<dynamic> incomingRequests;
  final List<dynamic> outgoingRequests;

  FriendState copyWith({
    List<dynamic>? friends,
    List<dynamic>? incomingRequests,
    List<dynamic>? outgoingRequests,
  }) {
    return FriendState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
    );
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendState>((
  ref,
) {
  return FriendsNotifier(ref);
});

class FriendsNotifier extends StateNotifier<FriendState> {
  FriendsNotifier(this.ref)
    : super(
        const FriendState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
        ),
      );

  final Ref ref;

  Future<void> loadFriends() async {
    final api = ref.read(apiServiceProvider);
    try {
      final friends = await api.getFriends();
      state = state.copyWith(friends: friends);
    } catch (_) {
      // Silent fail - populated on next load
    }
  }

  Future<void> loadRequests() async {
    final api = ref.read(apiServiceProvider);
    try {
      final requests = await api.getFriendRequests();
      state = state.copyWith(incomingRequests: requests);
    } catch (_) {
      // Silent fail
    }
  }

  Future<void> sendRequest(String toFirebaseUid) async {
    final api = ref.read(apiServiceProvider);
    await api.sendFriendRequest(toFirebaseUid: toFirebaseUid);
    await loadRequests();
  }

  Future<void> acceptRequest(int requestId) async {
    final api = ref.read(apiServiceProvider);
    await api.acceptFriendRequest(requestId);
    await loadFriends();
    await loadRequests();
  }

  Future<void> rejectRequest(int requestId) async {
    final api = ref.read(apiServiceProvider);
    await api.rejectFriendRequest(requestId);
    await loadRequests();
  }

  Future<void> remove(int friendId) async {
    final api = ref.read(apiServiceProvider);
    await api.removeFriend(friendId);
    await loadFriends();
  }
}
