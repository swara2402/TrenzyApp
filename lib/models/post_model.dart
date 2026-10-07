import 'user_model.dart';
import 'product_model.dart';

class PostModel {
  final String id;
  final UserModel? author;
  final String content;
  final String title;
  final String description;
  final String attachment;
  final List<String> imageUrls;
  final List<ProductModel> products;
  final int likes;
  final int comments;
  final bool isLiked;
  final DateTime? createdAt;
  final bool isLoaded;

  PostModel({
    String? id,
    this.author,
    String? content,
    String? title,
    String? description,
    String? attachment,
    List<String>? imageUrls,
    List<ProductModel>? products,
    int? likes,
    int? comments,
    bool? isLiked,
    this.createdAt,
    bool? isLoaded,
  })  : id = id ?? '',
        content = content ?? '',
        title = title ?? '',
        description = description ?? '',
        attachment = attachment ?? '',
        imageUrls = imageUrls ?? const [],
        products = products ?? const [],
        likes = likes ?? 0,
        comments = comments ?? 0,
        isLiked = isLiked ?? false,
        isLoaded = isLoaded ?? false;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final images = (json['imageUrls'] as List<dynamic>?)?.cast<String>();
    return PostModel(
      id: json['id']?.toString(),
      author: json['author'] != null
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      content: json['content'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      attachment: json['attachment'] as String? ?? (images?.isNotEmpty == true ? images!.first : null),
      imageUrls: images,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      likes: json['likes'] as int?,
      comments: json['comments'] as int?,
      isLiked: json['isLiked'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author?.toJson(),
      'content': content,
      'title': title,
      'description': description,
      'attachment': attachment,
      'imageUrls': imageUrls,
      'products': products.map((item) => item.toJson()).toList(),
      'likes': likes,
      'comments': comments,
      'isLiked': isLiked,
      'createdAt': createdAt?.toIso8601String(),
      'isLoaded': isLoaded,
    };
  }
}

// Type alias for Post (used by posts_provider)
typedef Post = PostModel;