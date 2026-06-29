class FriendModel {
  const FriendModel({
    required this.id,
    required this.friendFirebaseUid,
    required this.friendName,
  });

  final int id;
  final String friendFirebaseUid;
  final String friendName;

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      friendFirebaseUid: json['friendFirebaseUid']?.toString() ?? '',
      friendName: json['friendName']?.toString() ?? 'Friend',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friendFirebaseUid': friendFirebaseUid,
      'friendName': friendName,
    };
  }
}

class FriendRequestModel {
  const FriendRequestModel({
    required this.id,
    required this.fromFirebaseUid,
    required this.fromName,
    required this.createdAt,
  });

  final int id;
  final String fromFirebaseUid;
  final String fromName;
  final DateTime createdAt;

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      fromFirebaseUid: json['fromFirebaseUid']?.toString() ?? '',
      fromName: json['fromName']?.toString() ?? 'User',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromFirebaseUid': fromFirebaseUid,
      'fromName': fromName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
