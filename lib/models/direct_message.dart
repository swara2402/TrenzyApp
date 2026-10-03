class DirectMessage {
  const DirectMessage({required this.id, required this.senderFirebaseUid, required this.recipientFirebaseUid, required this.message, required this.createdAt});
  final int id;
  final String senderFirebaseUid;
  final String recipientFirebaseUid;
  final String message;
  final DateTime createdAt;
  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    senderFirebaseUid: json['senderFirebaseUid']?.toString() ?? '',
    recipientFirebaseUid: json['recipientFirebaseUid']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
