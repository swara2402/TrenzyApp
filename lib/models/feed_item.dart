class FeedItem {
  final String id;
  final String userId;
  final String content;
  final String title;
  final String description;
  final String imageUrl;
  final int likes;
  final int comments;
  final DateTime createdAt;

  FeedItem({
    String? id,
    String? userId,
    String? content,
    String? title,
    String? description,
    String? imageUrl,
    int? likes,
    int? comments,
    DateTime? createdAt,
  })  : id = id ?? '',
        userId = userId ?? '',
        content = content ?? '',
        title = title ?? 'Untitled',
        description = description ?? '',
        imageUrl = imageUrl ?? '',
        likes = likes ?? 0,
        comments = comments ?? 0,
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      content: json['content'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      likes: json['likes'] as int?,
      comments: json['comments'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'likes': likes,
      'comments': comments,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}