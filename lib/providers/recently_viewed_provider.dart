import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service_provider.dart';

final recentlyViewedProvider =
    StateNotifierProvider.autoDispose<RecentlyViewedNotifier, List<String>>(
      (ref) => RecentlyViewedNotifier(ref),
    );

class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier(this._ref) : super([]);

  final Ref _ref;

  Future<void> add(String productId) async {
    // First update local state
    state = [productId, ...state.where((id) => id != productId)];

    if (state.length > 15) {
      state = state.sublist(0, 15);
    }

    // Then track to backend for trend analytics
    try {
      final api = _ref.read(apiServiceProvider);
      await api.trackProductView(productId);
    } catch (_) {
      // Silently fail - view is still tracked locally
    }
  }

  void clear() {
    state = [];
  }
}
