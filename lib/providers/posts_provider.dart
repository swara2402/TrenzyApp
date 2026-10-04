import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import '../models/post_model.dart';

final userPostsProvider = FutureProvider.autoDispose.family<List<Post>, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getUserPosts(userId: userId);
  return (response['posts'] as List).map((data) => Post.fromJson(data)).toList();
});