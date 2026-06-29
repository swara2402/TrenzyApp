class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.attachedProductId,
    this.attachedProductTitle,
    this.attachedProductImage,
    this.attachedProductPrice,
  });

  final int id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;

  // Product sharing support
  final String? attachedProductId;
  final String? attachedProductTitle;
  final String? attachedProductImage;
  final String? attachedProductPrice;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: (json['id'] as num).toInt(),
      groupId: json['groupId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Guest',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      ),
      attachedProductId: json['attachedProductId']?.toString(),
      attachedProductTitle: json['attachedProductTitle']?.toString(),
      attachedProductImage: json['attachedProductImage']?.toString(),
      attachedProductPrice: json['attachedProductPrice']?.toString(),
    );
  }
}
