import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_models.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

class FeedSection {
  final String id;
  final String title;
  final String type;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> posts;

  const FeedSection({
    required this.id,
    required this.title,
    required this.type,
    this.products = const [],
    this.posts = const [],
  });

  factory FeedSection.fromJson(Map<String, dynamic> json) {
    return FeedSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'products',
      products:
          (json['products'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      posts:
          (json['posts'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }
}

class FeedData {
  final List<FeedSection> sections;
  final int offset;
  final int limit;

  const FeedData({required this.sections, this.offset = 0, this.limit = 20});

  factory FeedData.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    return FeedData(
      sections:
          (json['sections'] as List?)
              ?.map(
                (e) =>
                    FeedSection.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      offset: pagination['offset'] as int? ?? 0,
      limit: pagination['limit'] as int? ?? 20,
    );
  }
}

final feedProvider = FutureProvider.autoDispose<FeedData>((ref) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const FeedData(sections: []);

  final api = ref.watch(apiServiceProvider);
  final data = await api.getFeed(offset: 0, limit: 20);
  return FeedData.fromJson(data);
});

final socialFeedProvider = FutureProvider.autoDispose<List<SocialActivity>>((
  ref,
) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const [];

  final api = ref.watch(apiServiceProvider);
  try {
    final data = await api.getActivity();
    final rawList = data['activities'] as List<dynamic>? ?? [];
    return rawList
        .map(
          (e) => SocialActivity.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  } catch (_) {
    return const [];
  }
});
