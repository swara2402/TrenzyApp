import 'user_model.dart';
import 'group_message.dart';

class SocialRoomState {
  final String? roomId;
  final String? roomName;
  final String? roomType;
  final List<UserModel>? participants;
  final List<GroupMessage>? messages;
  final UserModel? createdBy;
  final DateTime? createdAt;
  final bool? isActive;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? unreadCount;

  SocialRoomState({
    this.roomId,
    this.roomName,
    this.roomType,
    this.participants,
    this.messages,
    this.createdBy,
    this.createdAt,
    this.isActive,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount,
  });

  factory SocialRoomState.fromJson(Map<String, dynamic> json, [dynamic options]) {
    return SocialRoomState(
      roomId: json['roomId'] as String?,
      roomName: json['roomName'] as String?,
      roomType: json['roomType'] as String?,
      participants: (json['participants'] as List<dynamic>?)
          ?.map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>?)
          ?.map((item) => GroupMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdBy: json['createdBy'] != null
          ? UserModel.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isActive: json['isActive'] as bool?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
      unreadCount: json['unreadCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'roomName': roomName,
        'roomType': roomType,
        'participants': participants?.map((item) => item.toJson()).toList(),
        'messages': messages?.map((item) => item.toJson()).toList(),
        'createdBy': createdBy?.toJson(),
        'createdAt': createdAt?.toIso8601String(),
        'isActive': isActive,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime?.toIso8601String(),
        'unreadCount': unreadCount,
      };
}