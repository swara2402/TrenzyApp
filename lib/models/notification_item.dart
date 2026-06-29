class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.kind,
    this.payload,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// e.g. "message", "payment", "vote", "invite"
  final String? kind;

  /// arbitrary extra details for deep linking
  final Map<String, dynamic>? payload;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      read: json['read'] == true,
      kind: json['kind']?.toString(),
      payload: (json['payload'] is Map)
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
      'kind': kind,
      'payload': payload,
    };
  }
}
