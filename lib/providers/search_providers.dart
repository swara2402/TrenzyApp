import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

final searchSuggestionsProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null) return const <String>[];

  final api = ref.watch(apiServiceProvider);
  try {
    final res = await api.getSuggestions(query.trim());
    return res.cast<String>();
  } catch (_) {
    return [];
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final debouncedSearchQueryProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(searchQueryProvider);
});
