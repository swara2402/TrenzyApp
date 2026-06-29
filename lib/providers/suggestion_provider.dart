import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/decision_flow.dart';
import 'auth_provider.dart';

final suggestionsProvider = FutureProvider.autoDispose
    .family<List<SuggestionOption>, String>((ref, query) async {
      final apiService = ref.watch(apiServiceProvider);

      if (query.trim().isEmpty) return [];

      // Real API call — errors propagate to the UI error state (shows retry button).
      final rawData = await apiService.getSuggestions(query);
      return rawData
          .map(
            (json) => SuggestionOption.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    });
