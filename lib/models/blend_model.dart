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
      id: json['id']?.toString(),
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
    final productJson = json['product'];
    return BlendRankedProduct(
      // The backend wraps winner entries as {"product": {...}, "score": ...},
      // while some payloads send the bare product object.
      product: productJson is Map
          ? ProductModel.fromJson(Map<String, dynamic>.from(productJson))
          : (json['id'] != null
              ? ProductModel.fromJson(json)
              : null),
      score: (json['score'] as num?)?.toDouble(),
      matchScore: (json['matchScore'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      likeCount: json['likeCount'] as int?,
      loveCount: json['loveCount'] as int?,
      isTie: json['isTie'] as bool?,
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

  /// Human readable compatibility label (e.g. "High"). The backend and the
  /// mock service both send a string; older payloads used a number, so the
  /// parser accepts either.
  final String? compatibilityLevel;
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

  static List<BlendRankedProduct>? _rankedList(dynamic value) {
    if (value is! List) return null;
    return value
        .whereType<Map>()
        .map(
          (item) =>
              BlendRankedProduct.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  factory BlendResults.fromJson(Map<String, dynamic> json) {
    // The live backend returns `winners` as a map keyed by category
    // ({"dresses": {"products": [...], "isTie": false}}) while legacy payloads
    // used a flat list of ranked products. Accept both, otherwise the cast
    // throws and the whole results screen fails to load.
    List<BlendRankedProduct>? winners;
    List<BlendCategoryWinner>? categoryWinners;
    final categoryRaw = json['categoryWinners'];
    if (categoryRaw is List) {
      categoryWinners = categoryRaw
          .whereType<Map>()
          .map(
            (item) => BlendCategoryWinner.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    final winnersRaw = json['winners'];
    if (winnersRaw is List) {
      winners = _rankedList(winnersRaw);
    } else if (winnersRaw is Map) {
      final flat = <BlendRankedProduct>[];
      final derived = <BlendCategoryWinner>[];
      winnersRaw.forEach((key, value) {
        if (value is! Map) return;
        final isTie = value['isTie'] == true;
        final ranked = <BlendRankedProduct>[];
        final products = value['products'];
        if (products is List) {
          for (final item in products) {
            if (item is! Map) continue;
            ranked.add(
              BlendRankedProduct.fromJson({
                ...Map<String, dynamic>.from(item),
                'isTie': isTie,
              }),
            );
          }
        }
        if (ranked.isEmpty) return;
        derived.add(
          BlendCategoryWinner(
            category: key.toString(),
            winner: ranked.first,
            products: ranked,
          ),
        );
        flat.add(ranked.first);
      });
      if (derived.isNotEmpty) categoryWinners = derived;
      winners = flat.isEmpty ? null : flat;
    }

    var recommendations = _rankedList(json['recommendations']);
    final recsRaw = json['blendRecommendations'];
    if (recommendations == null && recsRaw is Map) {
      final flat = <BlendRankedProduct>[];
      for (final value in recsRaw.values) {
        if (value is! List) continue;
        for (final item in value) {
          if (item is! Map) continue;
          flat.add(
            BlendRankedProduct.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      if (flat.isNotEmpty) recommendations = flat;
    }

    final overallRaw = json['overallWinner'];
    final compatRaw = json['compatibilityLevel'];

    return BlendResults(
      groups: json['groups'] is List
          ? (json['groups'] as List)
              .whereType<Map>()
              .map(
                (item) => BlendGroup.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
          : null,
      topProducts: _rankedList(json['topProducts']),
      winners: winners,
      overallWinner: overallRaw is Map
          ? BlendRankedProduct.fromJson(Map<String, dynamic>.from(overallRaw))
          : null,
      categoryWinners: categoryWinners,
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
      compatibilityLevel: compatRaw is String
          ? compatRaw
          : compatRaw is num
          ? compatRaw.toString()
          : null,
      totalSwipes: (json['totalSwipes'] as num?)?.toInt(),
      memberCount: (json['memberCount'] as num?)?.toInt(),
      recommendations: recommendations,
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