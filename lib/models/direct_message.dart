/// A persisted one-to-one direct chat message.
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderFirebaseUid,
    required this.recipientFirebaseUid,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String conversationId;
  final String senderFirebaseUid;
  final String recipientFirebaseUid;
  final String message;
  final DateTime createdAt;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderFirebaseUid: (json['senderFirebaseUid'] ?? '').toString(),
      recipientFirebaseUid: (json['recipientFirebaseUid'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.parse((json['createdAt'] ?? '').toString()),
    );
  }
}
