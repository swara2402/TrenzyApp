import 'product_model.dart';

class WardrobeItem {
  final String id;
  final String userId;
  final String name;
  final String imageUrl;
  final ProductModel? product;
  final DateTime? addedAt;
  final bool isFavorite;
  final List<String> tags;
  final String category;
  final String brand;
  final String color;
  final String season;
  final String occasion;
  final bool isLoaded;

  WardrobeItem({
    String? id,
    String? userId,
    String? name,
    String? imageUrl,
    this.product,
    this.addedAt,
    bool? isFavorite,
    List<String>? tags,
    String? category,
    String? brand,
    String? color,
    String? season,
    String? occasion,
    bool? isLoaded,
  })  : id = id ?? '',
        userId = userId ?? '',
        name = name ?? '',
        imageUrl = imageUrl ?? '',
        isFavorite = isFavorite ?? false,
        tags = tags ?? const [],
        category = category ?? '',
        brand = brand ?? '',
        color = color ?? '',
        season = season ?? '',
        occasion = occasion ?? '',
        isLoaded = isLoaded ?? false;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : null,
      isFavorite: json['isFavorite'] as bool?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      season: json['season'] as String?,
      occasion: json['occasion'] as String?,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'imageUrl': imageUrl,
      'product': product?.toJson(),
      'addedAt': addedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'tags': tags,
      'category': category,
      'brand': brand,
      'color': color,
      'season': season,
      'occasion': occasion,
      'isLoaded': isLoaded,
    };
  }
}

class Outfit {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String imageUrl;
  final String occasion;
  final String season;
  final List<WardrobeItem> items;
  final List<String> wardrobeItemIds;
  final bool isFavorite;
  final DateTime? createdAt;
  final bool isLoaded;

  Outfit({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? imageUrl,
    String? occasion,
    String? season,
    List<WardrobeItem>? items,
    List<String>? wardrobeItemIds,
    bool? isFavorite,
    this.createdAt,
    bool? isLoaded,
  })  : id = id ?? '',
        userId = userId ?? '',
        name = name ?? '',
        description = description ?? '',
        imageUrl = imageUrl ?? '',
        occasion = occasion ?? '',
        season = season ?? '',
        items = items ?? const [],
        wardrobeItemIds = wardrobeItemIds ?? const [],
        isFavorite = isFavorite ?? false,
        isLoaded = isLoaded ?? false;

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      occasion: json['occasion'] as String?,
      season: json['season'] as String?,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      wardrobeItemIds: (json['wardrobeItemIds'] as List<dynamic>?)?.cast<String>(),
      isFavorite: json['isFavorite'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'occasion': occasion,
      'season': season,
      'items': items.map((item) => item.toJson()).toList(),
      'wardrobeItemIds': wardrobeItemIds,
      'isFavorite': isFavorite,
      'createdAt': createdAt?.toIso8601String(),
      'isLoaded': isLoaded,
    };
  }
}

class OutfitIdea {
  final String? id;
  final String? name;
  final String? title;
  final String? description;
  final String? imageUrl;
  final List<WardrobeItem>? recommendedItems;
  final double? matchScore;
  final bool? isLoaded;

  OutfitIdea({
    this.id,
    this.name,
    this.title,
    this.description,
    this.imageUrl,
    this.recommendedItems,
    this.matchScore,
    this.isLoaded,
  });

  factory OutfitIdea.fromJson(Map<String, dynamic> json) {
    return OutfitIdea(
      id: json['id'] as String?,
      name: json['name'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      recommendedItems: (json['recommendedItems'] as List<dynamic>?)
          ?.map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      matchScore: (json['matchScore'] as num?)?.toDouble(),
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'recommendedItems': recommendedItems?.map((item) => item.toJson()).toList(),
      'matchScore': matchScore,
      'isLoaded': isLoaded,
    };
  }
}

class WardrobeState {
  final List<WardrobeItem>? items;
  final List<Outfit>? outfits;
  final List<OutfitIdea>? outfitIdeas;
  final bool? isLoading;
  final String? error;
  final bool? isLoaded;

  WardrobeState({
    this.items,
    this.outfits,
    this.outfitIdeas,
    this.isLoading,
    this.error,
    this.isLoaded,
  });

  factory WardrobeState.fromJson(Map<String, dynamic> json) {
    return WardrobeState(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      outfits: (json['outfits'] as List<dynamic>?)
          ?.map((item) => Outfit.fromJson(item as Map<String, dynamic>))
          .toList(),
      outfitIdeas: (json['outfitIdeas'] as List<dynamic>?)
          ?.map((item) => OutfitIdea.fromJson(item as Map<String, dynamic>))
          .toList(),
      isLoading: json['isLoading'] as bool?,
      error: json['error'] as String?,
      isLoaded: json['isLoaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items?.map((item) => item.toJson()).toList(),
      'outfits': outfits?.map((item) => item.toJson()).toList(),
      'outfitIdeas': outfitIdeas?.map((item) => item.toJson()).toList(),
      'isLoading': isLoading,
      'error': error,
      'isLoaded': isLoaded,
    };
  }
}

/// Represents a single DNA tag item (color, brand, category, etc.)
class StyleDnaItem {
  final String name;
  final double confidence;
  final String? hex;

  StyleDnaItem({
    required this.name,
    required this.confidence,
    this.hex,
  });

  factory StyleDnaItem.fromJson(Map<String, dynamic> json) {
    return StyleDnaItem(
      name: (json['name'] as String?) ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      hex: json['hex'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'confidence': confidence,
        'hex': hex,
      };
}

/// Style DNA describing a user's fashion profile
class StyleDna {
  final List<StyleDnaItem> colors;
  final List<StyleDnaItem> brands;
  final List<StyleDnaItem> categories;
  final List<StyleDnaItem> aesthetics;
  final List<StyleDnaItem> occasions;

  StyleDna({
    this.colors = const [],
    this.brands = const [],
    this.categories = const [],
    this.aesthetics = const [],
    this.occasions = const [],
  });

  factory StyleDna.fromJson(Map<String, dynamic> json) {
    List<StyleDnaItem> parseList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List<dynamic>)
          .map((e) => StyleDnaItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return StyleDna(
      colors: parseList(json['colors']),
      brands: parseList(json['brands']),
      categories: parseList(json['categories']),
      aesthetics: parseList(json['aesthetics']),
      occasions: parseList(json['occasions']),
    );
  }

  Map<String, dynamic> toJson() => {
        'colors': colors.map((e) => e.toJson()).toList(),
        'brands': brands.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'aesthetics': aesthetics.map((e) => e.toJson()).toList(),
        'occasions': occasions.map((e) => e.toJson()).toList(),
      };
}

/// Represents the user's AI-generated style persona
class StylePersona {
  final int id;
  final String name;
  final String description;
  final List<String> keywords;
  final List<String> colorPalette;
  final StyleDna? dna;

  StylePersona({
    this.id = 0,
    this.name = '',
    this.description = '',
    this.keywords = const [],
    this.colorPalette = const [],
    this.dna,
  });

  factory StylePersona.fromJson(Map<String, dynamic> json) {
    return StylePersona(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      keywords: (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      colorPalette: (json['colorPalette'] as List<dynamic>?)?.cast<String>() ?? [],
      dna: json['dna'] != null
          ? StyleDna.fromJson(json['dna'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'keywords': keywords,
        'colorPalette': colorPalette,
        'dna': dna?.toJson(),
      };
}

/// Response from wardrobe recommendations API
class WardrobeRecommendationsResponse {
  final List<WardrobeItem> items;
  final List<OutfitIdea> outfitIdeas;

  WardrobeRecommendationsResponse({
    this.items = const [],
    this.outfitIdeas = const [],
  });

  factory WardrobeRecommendationsResponse.fromJson(Map<String, dynamic> json) {
    return WardrobeRecommendationsResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      outfitIdeas: (json['outfitIdeas'] as List<dynamic>?)
              ?.map((e) => OutfitIdea.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'outfitIdeas': outfitIdeas.map((e) => e.toJson()).toList(),
      };
}