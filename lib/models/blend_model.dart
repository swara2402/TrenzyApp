// import 'package:flutter/material.dart';
import 'product_model.dart';

/// Blend Member Model
class BlendMember {
  const BlendMember({
    required this.userId,
    required this.userName,
    this.swipeCount = 0,
  });

  factory BlendMember.fromJson(Map<String, dynamic> json) {
    return BlendMember(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Guest',
      swipeCount: (json['swipeCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String userId;
  final String userName;
  final int swipeCount;
}

/// Blend Group Model
class BlendGroup {
  const BlendGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    this.memberCount = 0,
    this.options = const [], // ✅ Added products
  });

  factory BlendGroup.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'] as List<dynamic>? ?? [];
    final members = membersRaw
        .map((e) => BlendMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final optionsRaw = json['options'] as List<dynamic>? ?? [];
    final options = optionsRaw
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return BlendGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      inviteCode:
          json['inviteCode']?.toString() ?? json['id']?.toString() ?? '',
      members: members,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? members.length,
      options: options,
    );
  }

  final String id;
  final String name;
  final String inviteCode;
  final List<BlendMember> members;
  final int memberCount;
  final List<ProductModel> options; // ✅ Uses ProductModel
}

/// ✅ REPLACED: BlendRankedProduct now uses ProductModel
class BlendRankedProduct {
  const BlendRankedProduct({
    required this.product,
    required this.score,
    this.loveCount = 0,
    this.likeCount = 0,
  });

  factory BlendRankedProduct.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>? ?? {};
    return BlendRankedProduct(
      product: ProductModel.fromJson(productMap),
      score: (json['score'] as num?)?.toInt() ?? 0,
      loveCount: (json['loveCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  final ProductModel product; // ✅ Uses ProductModel
  final int score;
  final int loveCount;
  final int likeCount;

  String get title => product.name; // ✅ Convenience getter
  String? get price => product.formattedPrice;
  String? get category => product.category;
}

/// ✅ UPDATED: Uses ProductModel
class BlendCategoryWinner {
  const BlendCategoryWinner({
    required this.category,
    required this.products,
    required this.isTie,
    required this.score,
  });

  factory BlendCategoryWinner.fromJson(
    String category,
    Map<String, dynamic> json,
  ) {
    final productsRaw = json['products'] as List<dynamic>? ?? [];
    return BlendCategoryWinner(
      category: category,
      products: productsRaw
          .map((e) => BlendRankedProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isTie: json['isTie'] == true,
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  final String category;
  final List<BlendRankedProduct> products;
  final bool isTie;
  final int score;
}

/// ✅ UPDATED: Uses ProductModel
class BlendResults {
  const BlendResults({
    required this.groupId,
    required this.groupName,
    required this.recommendations,
    required this.winners,
    this.memberCount = 0,
    this.overallTie = false,
    this.totalSwipes = 0,
    this.overallWinner,
  });

  factory BlendResults.fromJson(Map<String, dynamic> json) {
    final recsRaw = json['blendRecommendations'] as Map<String, dynamic>? ?? {};
    final recommendations = <String, List<BlendRankedProduct>>{};
    for (final entry in recsRaw.entries) {
      final items = entry.value as List<dynamic>? ?? [];
      recommendations[entry.key] = items
          .map((e) => BlendRankedProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final winnersRaw = json['winners'] as Map<String, dynamic>? ?? {};
    final winners = winnersRaw.entries
        .map(
          (e) => BlendCategoryWinner.fromJson(
            e.key,
            Map<String, dynamic>.from(e.value as Map),
          ),
        )
        .toList();

    BlendRankedProduct? overall;
    final overallRaw = json['overallWinner'];
    if (overallRaw is Map) {
      overall = BlendRankedProduct.fromJson(
        Map<String, dynamic>.from(overallRaw),
      );
    }

    return BlendResults(
      groupId: json['groupId']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      recommendations: recommendations,
      winners: winners,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      overallTie: json['overallTie'] == true,
      totalSwipes: (json['totalSwipes'] as num?)?.toInt() ?? 0,
      overallWinner: overall,
    );
  }

  final String groupId;
  final String groupName;
  final Map<String, List<BlendRankedProduct>> recommendations;
  final List<BlendCategoryWinner> winners;
  final int memberCount;
  final bool overallTie;
  final int totalSwipes;
  final BlendRankedProduct? overallWinner;
}

/// Blend Live State
class BlendLiveState {
  const BlendLiveState({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.memberCount,
    required this.totalSwipes,
    this.lastEvent,
  });

  factory BlendLiveState.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'] as List<dynamic>? ?? [];
    return BlendLiveState(
      groupId: json['groupId']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      members: membersRaw
          .map((e) => BlendMember.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      totalSwipes: (json['totalSwipes'] as num?)?.toInt() ?? 0,
      lastEvent: json['lastEvent'] is Map
          ? Map<String, dynamic>.from(json['lastEvent'] as Map)
          : null,
    );
  }

  final String groupId;
  final String groupName;
  final List<BlendMember> members;
  final int memberCount;
  final int totalSwipes;
  final Map<String, dynamic>? lastEvent;
}

enum SwipeType { dislike, like, love }

String swipeTypeToApi(SwipeType type) {
  switch (type) {
    case SwipeType.dislike:
      return 'dislike';
    case SwipeType.like:
      return 'like';
    case SwipeType.love:
      return 'love';
  }
}
