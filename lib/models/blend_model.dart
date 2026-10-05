import 'product_model.dart';

/// Swipe action types for blend sessions
enum SwipeType { like, dislike, love, pass, superLike }

/// A member within a blend live session
class BlendMember {
  final String userId;
  final String userName;
  final String avatarUrl;
  final bool isOnline;
  final bool isReady;
  final int swipeCount;
  final DateTime? joinedAt;

  BlendMember({
    String? userId,
    String? userName,
    String? avatarUrl,
    bool? isOnline,
    bool? isReady,
    int? swipeCount,
    this.joinedAt,
  })  : userId = userId ?? '',
        userName = userName ?? '',
        avatarUrl = avatarUrl ?? '',
        isOnline = isOnline ?? false,
        isReady = isReady ?? true,
        swipeCount = swipeCount ?? 0;

  factory BlendMember.fromJson(Map<String, dynamic> json) {
    return BlendMember(
      userId: json['userId'] as String?,
      userName: json['userName'] as String? ?? json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isOnline: json['isOnline'] as bool?,
      swipeCount: (json['swipeCount'] as num?)?.toInt() ?? 0,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'avatarUrl': avatarUrl,
        'isOnline': isOnline,
        'swipeCount': swipeCount,
        'joinedAt': joinedAt?.toIso8601String(),
      };
}

/// Live state of a blend session received via WebSocket
class BlendLiveState {
  final String? groupId;
  final List<BlendMember> members;
  final List<String> onlineUserIds;
  final int totalSwipes;
  final ProductModel? currentProduct;
  final bool? isResultsReady;
  final double? agreementScore;
  final Map<String, int>? _swipesByMemberMap;

  int get memberCount => members.isNotEmpty ? members.length : onlineUserIds.length;
  Map<String, int> get swipesByMember => _swipesByMemberMap ?? {
    for (var m in members) m.userId: m.swipeCount
  };

  BlendLiveState({
    this.groupId,
    this.members = const [],
    this.onlineUserIds = const [],
    this.totalSwipes = 0,
    this.currentProduct,
    this.isResultsReady,
    this.agreementScore,
    Map<String, int>? swipesByMemberMap,
  }) : _swipesByMemberMap = swipesByMemberMap;

  factory BlendLiveState.fromJson(Map<String, dynamic> json) {
    return BlendLiveState(
      groupId: json['groupId'] as String?,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => BlendMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      onlineUserIds:
          (json['onlineUserIds'] as List<dynamic>?)?.cast<String>() ?? [],
      totalSwipes: (json['totalSwipes'] as num?)?.toInt() ?? 0,
      currentProduct: json['currentProduct'] != null
          ? ProductModel.fromJson(
              json['currentProduct'] as Map<String, dynamic>)
          : null,
      isResultsReady: json['isResultsReady'] as bool?,
      agreementScore: (json['agreementScore'] as num?)?.toDouble(),
      swipesByMemberMap: (json['swipesByMember'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'members': members.map((e) => e.toJson()).toList(),
        'onlineUserIds': onlineUserIds,
        'totalSwipes': totalSwipes,
        'currentProduct': currentProduct?.toJson(),
        'isResultsReady': isResultsReady,
        'agreementScore': agreementScore,
        'swipesByMember': swipesByMember,
      };
}

class BlendGroup {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final int memberCount;
  final List<BlendMember> members;
  final List<BlendRankedProduct> products;
  final List<ProductModel> options;

  BlendGroup({
    String? id,
    String? name,
    String? description,
    String? inviteCode,
    int? memberCount,
    List<BlendMember>? members,
    List<BlendRankedProduct>? products,
    List<ProductModel>? options,
  })  : id = id ?? '',
        name = name ?? '',
        description = description ?? '',
        inviteCode = inviteCode ?? '',
        memberCount = memberCount ?? 0,
        members = members ?? const [],
        products = products ?? const [],
        options = options ?? const [];

  factory BlendGroup.fromJson(Map<String, dynamic> json) {
    return BlendGroup(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String?,
      memberCount: json['memberCount'] as int?,
      members: (json['members'] as List<dynamic>?)
          ?.map((item) => BlendMember.fromJson(item as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>?)
          ?.map((item) =>
              BlendRankedProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      options: (json['options'] as List<dynamic>?)
          ?.map((item) =>
              ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'memberCount': memberCount,
      'members': members.map((item) => item.toJson()).toList(),
      'products': products.map((item) => item.toJson()).toList(),
      'options': options.map((item) => item.toJson()).toList(),
    };
  }
}

class BlendRankedProduct {
  final ProductModel? product;
  final double? score;
  final double? matchScore;
  final int? rank;
  final int? likeCount;
  final int? loveCount;
  final bool? isTie;
  final List<ProductModel>? products;

  String? get category => product?.category;

  BlendRankedProduct({
    this.product,
    this.score,
    this.matchScore,
    this.rank,
    this.likeCount,
    this.loveCount,
    this.isTie,
    this.products,
  });

  factory BlendRankedProduct.fromJson(Map<String, dynamic> json) {
    return BlendRankedProduct(
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      score: (json['score'] as num?)?.toDouble(),
      matchScore: (json['matchScore'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      likeCount: json['likeCount'] as int?,
      loveCount: json['loveCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product?.toJson(),
      'score': score,
      'matchScore': matchScore,
      'rank': rank,
      'likeCount': likeCount,
      'loveCount': loveCount,
    };
  }
}

class BlendCategoryWinner {
  final String? category;
  final BlendRankedProduct? winner;
  final List<BlendRankedProduct>? products;

  BlendCategoryWinner({
    this.category,
    this.winner,
    this.products,
  });

  factory BlendCategoryWinner.fromJson(Map<String, dynamic> json) {
    return BlendCategoryWinner(
      category: json['category'] as String?,
      winner: json['winner'] != null
          ? BlendRankedProduct.fromJson(json['winner'] as Map<String, dynamic>)
          : null,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) =>
              BlendRankedProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'winner': winner?.toJson(),
      'products': products?.map((item) => item.toJson()).toList(),
    };
  }
}

class BlendResults {
  final List<BlendGroup>? groups;
  final List<BlendRankedProduct>? topProducts;
  final List<BlendRankedProduct>? winners;
  final BlendRankedProduct? overallWinner;
  final List<BlendCategoryWinner>? categoryWinners;
  final String? summary;
  final String? groupId;
  final List<String>? sharedBrands;
  final List<String>? sharedStyles;
  final List<String>? sharedColours;
  final List<String>? sharedCategories;
  final double? wardrobeOverlap;
  final double? fashionScore;
  final String? groupName;
  final double? compatibilityLevel;
  final int? totalSwipes;
  final int? memberCount;
  final List<BlendRankedProduct>? recommendations;

  BlendResults({
    this.groups,
    this.topProducts,
    this.winners,
    this.overallWinner,
    this.categoryWinners,
    this.summary,
    this.groupId,
    this.sharedBrands,
    this.sharedStyles,
    this.sharedColours,
    this.sharedCategories,
    this.wardrobeOverlap,
    this.fashionScore,
    this.groupName,
    this.compatibilityLevel,
    this.totalSwipes,
    this.memberCount,
    this.recommendations,
  });

  factory BlendResults.fromJson(Map<String, dynamic> json) {
    return BlendResults(
      groups: (json['groups'] as List<dynamic>?)
          ?.map((item) => BlendGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
      topProducts: (json['topProducts'] as List<dynamic>?)
          ?.map((item) =>
              BlendRankedProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      winners: (json['winners'] as List<dynamic>?)
          ?.map((item) =>
              BlendRankedProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      overallWinner: json['overallWinner'] != null
          ? BlendRankedProduct.fromJson(
              json['overallWinner'] as Map<String, dynamic>)
          : null,
      categoryWinners: (json['categoryWinners'] as List<dynamic>?)
          ?.map((item) =>
              BlendCategoryWinner.fromJson(item as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String?,
      groupId: json['groupId'] as String?,
      sharedBrands: (json['sharedBrands'] as List<dynamic>?)?.cast<String>(),
      sharedStyles: (json['sharedStyles'] as List<dynamic>?)?.cast<String>(),
      sharedColours: (json['sharedColours'] as List<dynamic>?)?.cast<String>(),
      sharedCategories:
          (json['sharedCategories'] as List<dynamic>?)?.cast<String>(),
      wardrobeOverlap: (json['wardrobeOverlap'] as num?)?.toDouble(),
      fashionScore: (json['fashionScore'] as num?)?.toDouble(),
      groupName: json['groupName'] as String?,
      compatibilityLevel: (json['compatibilityLevel'] as num?)?.toDouble(),
      totalSwipes: json['totalSwipes'] as int?,
      memberCount: json['memberCount'] as int?,
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((item) =>
              BlendRankedProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groups': groups?.map((item) => item.toJson()).toList(),
      'topProducts': topProducts?.map((item) => item.toJson()).toList(),
      'winners': winners?.map((item) => item.toJson()).toList(),
      'overallWinner': overallWinner?.toJson(),
      'categoryWinners': categoryWinners?.map((item) => item.toJson()).toList(),
      'summary': summary,
      'groupId': groupId,
      'sharedBrands': sharedBrands,
      'sharedStyles': sharedStyles,
      'sharedColours': sharedColours,
      'sharedCategories': sharedCategories,
      'wardrobeOverlap': wardrobeOverlap,
      'fashionScore': fashionScore,
      'groupName': groupName,
      'compatibilityLevel': compatibilityLevel,
      'totalSwipes': totalSwipes,
      'memberCount': memberCount,
      'recommendations': recommendations?.map((item) => item.toJson()).toList(),
    };
  }
}