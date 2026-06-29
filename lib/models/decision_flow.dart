// lib/models/decision_flow.dart

import 'package:flutter/material.dart';

import 'product_model.dart';

/// ============================================================
/// HELPER FUNCTIONS
/// ============================================================

/// Parse hex color string to Color
Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// Extension to convert Color to hex string
extension ColorExtension on Color {
  String toHex() {
    return '#${(toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

/// ============================================================
/// SUGGESTION OPTION - AI Wrapper around ProductModel
/// ============================================================

class SuggestionOption {
  const SuggestionOption({
    required this.product,
    required this.matchScore,
    this.gradient = const [Color(0xFFF4F1E8), Color(0xFFE4DBBC)],
    this.silhouetteColor = const Color(0xFFB2A257),
  });

  factory SuggestionOption.fromJson(Map<String, dynamic> json) {
    // Parse gradient
    List<Color> parseGradient(dynamic gradientData) {
      if (gradientData is List) {
        return gradientData.map((e) => _parseColor(e.toString())).toList();
      }
      return const [Color(0xFFF4F1E8), Color(0xFFE4DBBC)];
    }

    final productJson = json.containsKey('product')
        ? json['product'] as Map<String, dynamic>? ?? {}
        : json;

    final id = productJson['id']?.toString() ?? '';
    final name =
        productJson['name']?.toString() ?? json['title']?.toString() ?? '';
    final brand =
        productJson['brand']?.toString() ?? json['subtitle']?.toString();

    double? price;
    final priceRaw = productJson['price'] ?? json['price'];
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw != null) {
      final cleanPrice = priceRaw.toString().replaceAll(RegExp(r'[^\d.]'), '');
      price = double.tryParse(cleanPrice);
    }

    final product = ProductModel(
      id: id,
      name: name,
      brand: brand,
      price: price,
      imageUrl:
          (productJson['image_url'] ??
                  productJson['imageUrl'] ??
                  json['imageUrl'])
              ?.toString(),
    );

    return SuggestionOption(
      product: product,
      matchScore: (json['matchScore'] as num?)?.toInt() ?? 0,
      gradient: parseGradient(json['gradient']),
      silhouetteColor: json['silhouetteColor'] != null
          ? _parseColor(json['silhouetteColor'].toString())
          : const Color(0xFFB2A257),
    );
  }

  final ProductModel product;
  final int matchScore;
  final List<Color> gradient;
  final Color silhouetteColor;

  // Convenience getters
  String get id => product.id;
  String get title => product.name;
  String get subtitle => product.brand ?? product.articleType ?? '';
  String get price => product.formattedPrice;
  String? get imageUrl => product.imageUrl;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'matchScore': matchScore,
    'gradient': gradient.map((c) => c.toHex()).toList(),
    'silhouetteColor': silhouetteColor.toHex(),
  };
}

/// ============================================================
/// ROUTE EXTRAS
/// ============================================================

class SuggestionsRouteExtra {
  const SuggestionsRouteExtra({required this.query, this.products = const []});

  final String query;
  final List<ProductModel> products;
}

class SocialRouteExtra {
  const SocialRouteExtra({
    required this.query,
    required this.selectedOptions,
    required this.roomId,
  });

  final String query;
  final List<SuggestionOption> selectedOptions;
  final String roomId;
}

/// ============================================================
/// SOCIAL REACTION
/// ============================================================

class SocialReaction {
  const SocialReaction({
    required this.friendName,
    required this.emoji,
    required this.note,
    required this.optionId,
  });

  final String friendName;
  final String emoji;
  final String note;
  final String optionId;

  factory SocialReaction.fromJson(Map<String, dynamic> json) {
    return SocialReaction(
      friendName: json['friendName']?.toString() ?? 'Friend',
      emoji: json['emoji']?.toString() ?? '\u{1F525}',
      note: json['note']?.toString() ?? 'Voted in the room.',
      optionId: json['optionId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'friendName': friendName,
    'emoji': emoji,
    'note': note,
    'optionId': optionId,
  };
}

/// ============================================================
/// DECISION ROUTE EXTRA
/// ============================================================

class DecisionRouteExtra {
  const DecisionRouteExtra({
    required this.query,
    required this.selectedOptions,
    required this.reactions,
  });

  final String query;
  final List<SuggestionOption> selectedOptions;
  final List<SocialReaction> reactions;
}

String buildRoomIdFromQuery(String query) {
  final normalized = query.trim().toLowerCase();
  final cleaned = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final collapsed = cleaned.replaceAll(RegExp(r'-{2,}'), '-');
  final roomId = collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
  return roomId.isEmpty ? 'social-room' : roomId;
}
