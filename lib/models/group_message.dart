import 'user_model.dart';

class GroupMessage {
  final String id;
  final String roomId;
  final String groupId;
  final String senderId;
  final String senderName;
  final UserModel? sender;
  final String content;
  final String message;
  final String type;
  final List<String> attachments;
  final String attachment;
  final String attachedProductId;
  final String attachedProductTitle;
  final String attachedProductImage;
  final String attachedProductPrice;
  final DateTime? createdAt;
  final bool isRead;
  final bool read;

  String? get displayName => senderName.isNotEmpty ? senderName : sender?.displayName ?? sender?.name;

  GroupMessage({
    String? id,
    String? roomId,
    String? groupId,
    String? senderId,
    String? senderName,
    String? displayName,
    this.sender,
    String? content,
    String? message,
    String? type,
    List<String>? attachments,
    String? attachment,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
    this.createdAt,
    bool? isRead,
    bool? read,
  })  : id = id ?? '',
        roomId = roomId ?? '',
        groupId = groupId ?? '',
        senderId = senderId ?? '',
        senderName = senderName ?? displayName ?? '',
        content = content ?? '',
        message = message ?? '',
        type = type ?? '',
        attachments = attachments ?? const [],
        attachment = attachment ?? '',
        attachedProductId = attachedProductId ?? '',
        attachedProductTitle = attachedProductTitle ?? '',
        attachedProductImage = attachedProductImage ?? '',
        attachedProductPrice = attachedProductPrice ?? '',
        isRead = isRead ?? read ?? false,
        read = read ?? isRead ?? false;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id']?.toString(),
      roomId: json['roomId'] as String?,
      groupId: json['groupId'] as String?,
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String? ?? json['displayName'] as String?,
      sender: json['sender'] != null
          ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      content: json['content'] as String?,
      message: json['message'] as String?,
      type: json['type'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>(),
      attachment: json['attachment'] as String?,
      attachedProductId: json['attachedProductId'] as String?,
      attachedProductTitle: json['attachedProductTitle'] as String?,
      attachedProductImage: json['attachedProductImage'] as String?,
      attachedProductPrice: json['attachedProductPrice'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isRead: json['isRead'] as bool?,
      read: json['read'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'sender': sender?.toJson(),
      'content': content,
      'message': message,
      'type': type,
      'attachments': attachments,
      'attachment': attachment,
      'attachedProductId': attachedProductId,
      'attachedProductTitle': attachedProductTitle,
      'attachedProductImage': attachedProductImage,
      'attachedProductPrice': attachedProductPrice,
      'createdAt': createdAt?.toIso8601String(),
      'isRead': isRead,
      'read': read,
    };
  }
}