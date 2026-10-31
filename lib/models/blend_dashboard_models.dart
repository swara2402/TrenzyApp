import 'user_model.dart';
import 'product_model.dart';
import 'blend_model.dart';
import 'wardrobe_model.dart';

class BlendDashboard {
  final String? id;
  final String? blendId;
  final String? name;
  final String? description;
  final int memberCount;
  final List<BlendMember> members;
  final List<SharedWishlistItem> wishlistItems;
  final int totalWishlistItems;
  final List<MoodboardItem> moodboardItems;
  final int totalMoodboardItems;
  final List<BlendInsight> insights;
  final List<ActivityEvent> recentActivity;
  final StyleDna? styleDNA;
  final double fashionScore;
  final String compatibilityLevel;
  final int totalSwipes;
  // Legacy fields kept for backward compat
  final List<SharedWishlistItem>? sharedWishlist;
  final List<MoodboardItem>? moodboard;
  final List<ActivityEvent>? activities;
  final DateTime? lastUpdated;
  final bool? isLoaded;

  BlendDashboard({
    this.id,
    this.blendId,
    this.name,
    this.description,
    this.memberCount = 0,
    this.members = const [],
    this.wishlistItems = const [],
    this.totalWishlistItems = 0,
    this.moodboardItems = const [],
    this.totalMoodboardItems = 0,
    this.insights = const [],
    this.recentActivity = const [],
    this.styleDNA,
    this.fashionScore = 0,
    this.compatibilityLevel = '',
    this.totalSwipes = 0,
    this.sharedWishlist,
    this.moodboard,
    this.activities,
    this.lastUpdated,
    this.isLoaded,
  });

  factory BlendDashboard.fromJson(Map<String, dynamic> json) {
    return BlendDashboard(
      id: json['id']?.toString(),
      blendId: json['blendId'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => BlendMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      wishlistItems:
          (json['wishlistItems'] as List<dynamic>?)
              ?.map(
                (e) => SharedWishlistItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      totalWishlistItems: (json['totalWishlistItems'] as num?)?.toInt() ?? 0,
      moodboardItems:
          (json['moodboardItems'] as List<dynamic>?)
              ?.map((e) => MoodboardItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalMoodboardItems: (json['totalMoodboardItems'] as num?)?.toInt() ?? 0,
      insights:
          (json['insights'] as List<dynamic>?)
              ?.map((e) => BlendInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentActivity:
          (json['recentActivity'] as List<dynamic>?)
              ?.map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      styleDNA: json['styleDNA'] != null
          ? StyleDna.fromJson(json['styleDNA'] as Map<String, dynamic>)
          : null,
      fashionScore: (json['fashionScore'] as num?)?.toDouble() ?? 0,
      compatibilityLevel: (json['compatibilityLevel'] as String?) ?? '',
      totalSwipes: (json['totalSwipes'] as num?)?.toInt() ?? 0,
      sharedWishlist: (json['sharedWishlist'] as List<dynamic>?)
          ?.map(
            (item) => SharedWishlistItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      moodboard: (json['moodboard'] as List<dynamic>?)
          ?.map((item) => MoodboardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      activities: (json['activities'] as List<dynamic>?)
          ?.map((item) => ActivityEvent.fromJson(item as Map<String, dynamic>))
          .toList(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blendId': blendId,
    'name': name,
    'description': description,
    'memberCount': memberCount,
    'members': members.map((e) => e.toJson()).toList(),
    'wishlistItems': wishlistItems.map((e) => e.toJson()).toList(),
    'totalWishlistItems': totalWishlistItems,
    'moodboardItems': moodboardItems.map((e) => e.toJson()).toList(),
    'totalMoodboardItems': totalMoodboardItems,
    'insights': insights.map((e) => e.toJson()).toList(),
    'recentActivity': recentActivity.map((e) => e.toJson()).toList(),
    'styleDNA': styleDNA?.toJson(),
    'fashionScore': fashionScore,
    'compatibilityLevel': compatibilityLevel,
    'totalSwipes': totalSwipes,
    'sharedWishlist': sharedWishlist?.map((item) => item.toJson()).toList(),
    'moodboard': moodboard?.map((item) => item.toJson()).toList(),
    'activities': activities?.map((item) => item.toJson()).toList(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'isLoaded': isLoaded,
  };
}

class SharedWishlistItem {
  final String? id;
  final ProductModel? product;
  final UserModel? addedBy;
  final String? addedByNameValue;
  final String? addedByUid;
  final DateTime? addedAt;
  final bool? isFavorite;
  final String? notes;
  final String? productUrl;
  final bool? isLoaded;
  final int likeCount;
  final int loveCount;
  final int dislikeCount;
  final int totalVotes;
  final double? ratingAverage;
  final String? myVote;
  final String? productIdValue;

  String get productId => productIdValue ?? product?.id ?? '';
  String get productName => product?.name ?? '';
  String get productImage => product?.imageUrl ?? '';
  String get productBrand => product?.brand ?? '';
  String get productCategory => product?.category ?? '';
  double get productPrice {
    final item = product;
    if (item == null) return 0.0;
    return item.effectivePrice > 0 ? item.effectivePrice : item.price;
  }

  bool get hasProductPrice => product?.hasPrice ?? false;
  String get addedByName =>
      (addedByNameValue?.trim().isNotEmpty ?? false)
          ? addedByNameValue!
          : (addedBy?.name ?? addedBy?.displayName ?? 'A blend member');
  DateTime? get createdAt => addedAt;

  SharedWishlistItem({
    this.id,
    this.product,
    this.addedBy,
    this.addedByNameValue,
    this.addedByUid,
    this.addedAt,
    this.isFavorite,
    this.notes,
    this.productUrl,
    this.isLoaded,
    this.likeCount = 0,
    this.loveCount = 0,
    this.dislikeCount = 0,
    this.totalVotes = 0,
    this.ratingAverage,
    this.myVote,
    this.productIdValue,
  });

  factory SharedWishlistItem.fromJson(Map<String, dynamic> json) {
    final nestedProduct = json['product'];
    final productJson = nestedProduct is Map
        ? Map<String, dynamic>.from(nestedProduct)
        : <String, dynamic>{
            'id': json['productId'],
            'name': json['productName'],
            'imageUrl': json['productImage'],
            'price': json['productPrice'],
            'brand': json['productBrand'],
            'category': json['productCategory'],
          };
    final addedByJson = json['addedBy'];
    return SharedWishlistItem(
      id: json['id']?.toString(),
      productIdValue: json['productId']?.toString(),
      product: productJson['id'] != null || productJson['name'] != null
          ? ProductModel.fromJson(productJson)
          : null,
      addedBy: addedByJson is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(addedByJson))
          : null,
      addedByNameValue: json['addedByName']?.toString(),
      addedByUid: json['addedByUid']?.toString(),
      addedAt: (json['addedAt'] ?? json['createdAt']) != null
          ? DateTime.tryParse((json['addedAt'] ?? json['createdAt']).toString())
          : null,
      isFavorite: json['isFavorite'] as bool?,
      notes: json['notes'] as String?,
      productUrl: (json['productUrl'] ?? json['purchaseLink']) as String?,
      isLoaded: json['isLoaded'] as bool?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      loveCount: (json['loveCount'] as num?)?.toInt() ?? 0,
      dislikeCount: (json['dislikeCount'] as num?)?.toInt() ?? 0,
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
      myVote: json['myVote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'product': product?.toJson(),
    'addedBy': addedBy?.toJson(),
    'addedByName': addedByName,
    'addedByUid': addedByUid,
    'addedAt': addedAt?.toIso8601String(),
    'isFavorite': isFavorite,
    'notes': notes,
    'productUrl': productUrl,
    'isLoaded': isLoaded,
    'likeCount': likeCount,
    'loveCount': loveCount,
    'dislikeCount': dislikeCount,
    'totalVotes': totalVotes,
    'ratingAverage': ratingAverage,
    'myVote': myVote,
  };
}

class MoodboardItem {
  final String id;
  final String imageUrl;
  final String caption;
  final String content;
  final String itemType;
  final UserModel? createdBy;
  final UserModel? addedBy;
  final List<String> tags;
  final DateTime? createdAt;
  final bool isLoaded;

  String get addedByName =>
      addedBy?.name ?? createdBy?.name ?? createdBy?.displayName ?? 'Anonymous';

  MoodboardItem({
    String? id,
    String? imageUrl,
    String? caption,
    String? content,
    String? itemType,
    this.createdBy,
    this.addedBy,
    List<String>? tags,
    this.createdAt,
    bool? isLoaded,
  }) : id = id ?? '',
       imageUrl = imageUrl ?? '',
       caption = caption ?? '',
       content = content ?? '',
       itemType = itemType ?? '',
       tags = tags ?? const [],
       isLoaded = isLoaded ?? false;

  factory MoodboardItem.fromJson(Map<String, dynamic> json) {
    return MoodboardItem(
      id: json['id']?.toString(),
      imageUrl: json['imageUrl'] as String?,
      caption: json['caption'] as String?,
      content: json['content'] as String?,
      itemType: json['itemType'] as String?,
      createdBy: json['createdBy'] != null
          ? UserModel.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      addedBy: json['addedBy'] != null
          ? UserModel.fromJson(json['addedBy'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
    'caption': caption,
    'content': content,
    'itemType': itemType,
    'createdBy': createdBy?.toJson(),
    'addedBy': addedBy?.toJson(),
    'tags': tags,
    'createdAt': createdAt?.toIso8601String(),
    'isLoaded': isLoaded,
  };
}

class BlendInsight {
  final String? id;
  final String? title;
  final String? description;
  final String? type;
  final double? matchScore;
  final double? confidence;
  final List<ProductModel>? recommendedProducts;
  final DateTime? generatedAt;
  final bool? isLoaded;

  BlendInsight({
    this.id,
    this.title,
    this.description,
    this.type,
    this.matchScore,
    this.confidence,
    this.recommendedProducts,
    this.generatedAt,
    this.isLoaded,
  });

  factory BlendInsight.fromJson(Map<String, dynamic> json) {
    return BlendInsight(
      id: json['id']?.toString(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      type: json['type'] as String?,
      matchScore: (json['matchScore'] as num?)?.toDouble(),
      confidence:
          (json['confidence'] as num?)?.toDouble() ??
          (json['matchScore'] as num?)?.toDouble(),
      recommendedProducts: (json['recommendedProducts'] as List<dynamic>?)
          ?.map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'matchScore': matchScore,
    'recommendedProducts': recommendedProducts
        ?.map((item) => item.toJson())
        .toList(),
    'generatedAt': generatedAt?.toIso8601String(),
    'isLoaded': isLoaded,
  };
}

class ActivityEvent {
  final String? id;
  final String? type;
  final String? description;
  final UserModel? user;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final bool? isLoaded;

  String get kind => type ?? '';

  ActivityEvent({
    this.id,
    this.type,
    this.description,
    this.user,
    this.metadata,
    this.createdAt,
    this.isLoaded,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id']?.toString(),
      type: json['type'] as String?,
      description: json['description'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'description': description,
    'user': user?.toJson(),
    'metadata': metadata,
    'createdAt': createdAt?.toIso8601String(),
    'isLoaded': isLoaded,
  };
}
