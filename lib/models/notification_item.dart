class NotificationItem {
  final String id;
  final String userId;
  final String type;
  final String kind;
  final String title;
  final String message;
  final String body;
  final String imageUrl;
  final bool isRead;
  final bool read;
  final DateTime createdAt;
  final String relatedId;
  final Map<String, dynamic> details;

  NotificationItem({
    String? id,
    String? userId,
    String? type,
    String? kind,
    String? title,
    String? message,
    String? body,
    String? imageUrl,
    bool? isRead,
    bool? read,
    DateTime? createdAt,
    String? relatedId,
    Map<String, dynamic>? details,
  })  : id = id ?? '',
        userId = userId ?? '',
        type = type ?? '',
        kind = kind ?? '',
        title = title ?? 'Notification',
        message = message ?? '',
        body = body ?? '',
        imageUrl = imageUrl ?? '',
        isRead = isRead ?? read ?? false,
        read = read ?? isRead ?? false,
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        relatedId = relatedId ?? '',
        details = details ?? const {};

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      type: json['type'] as String?,
      kind: json['kind'] as String?,
      title: json['title'] as String?,
      message: json['message'] as String?,
      body: json['body'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isRead: json['isRead'] as bool?,
      read: json['read'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      relatedId: json['relatedId'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'kind': kind,
      'title': title,
      'message': message,
      'body': body,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
      'relatedId': relatedId,
      'details': details,
    };
  }
}