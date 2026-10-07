import 'user_model.dart';

class Friend {
  final String? id;
  final String? name;
  final String? avatarUrl;
  final String? firebaseUid;
  final UserModel? user;
  final DateTime? since;

  Friend({
    this.id,
    this.name,
    this.avatarUrl,
    this.firebaseUid,
    this.user,
    this.since,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      firebaseUid: json['firebaseUid'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      since: json['since'] != null
          ? DateTime.parse(json['since'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'firebaseUid': firebaseUid,
      'user': user?.toJson(),
      'since': since?.toIso8601String(),
    };
  }
}

class FriendRequestItem {
  final String? id;
  final String? fromFirebaseUid;
  final String? fromName;
  final String? toFirebaseUid;
  final UserModel? fromUser;
  final DateTime? sentAt;

  FriendRequestItem({
    this.id,
    this.fromFirebaseUid,
    this.fromName,
    this.toFirebaseUid,
    this.fromUser,
    this.sentAt,
  });

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) {
    return FriendRequestItem(
      id: json['id']?.toString(),
      fromFirebaseUid: json['fromFirebaseUid'] as String?,
      fromName: json['fromName'] as String?,
      toFirebaseUid: json['toFirebaseUid'] as String?,
      fromUser: json['fromUser'] != null
          ? UserModel.fromJson(json['fromUser'] as Map<String, dynamic>)
          : null,
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromFirebaseUid': fromFirebaseUid,
      'fromName': fromName,
      'toFirebaseUid': toFirebaseUid,
      'fromUser': fromUser?.toJson(),
      'sentAt': sentAt?.toIso8601String(),
    };
  }
}

class FriendSuggestion {
  final String? name;
  final String? firebaseUid;
  final String? reason;
  final UserModel? user;
  final int? mutualFriends;

  FriendSuggestion({
    this.name,
    this.firebaseUid,
    this.reason,
    this.user,
    this.mutualFriends,
  });

  factory FriendSuggestion.fromJson(Map<String, dynamic> json) {
    return FriendSuggestion(
      name: json['name'] as String?,
      firebaseUid: json['firebaseUid'] as String?,
      reason: json['reason'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      mutualFriends: json['mutualFriends'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'firebaseUid': firebaseUid,
      'reason': reason,
      'user': user?.toJson(),
      'mutualFriends': mutualFriends,
    };
  }
}