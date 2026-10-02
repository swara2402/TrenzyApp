import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_service.dart';

void trackEvent(WidgetRef ref, String name, [Map<String, Object?> params = const {}]) {
  try {
    ref.read(analyticsServiceProvider).logEvent(name: name, parameters: params);
  } catch (_) {}
}

void trackProductView(WidgetRef ref, String productId, String productName) {
  trackEvent(ref, 'product_view', {
    'product_id': productId,
    'product_name': productName,
  });
}

void trackProductSave(WidgetRef ref, String productId) {
  trackEvent(ref, 'product_save', {'product_id': productId});
}

void trackAffiliateClick(WidgetRef ref, String productId, {String? partner}) {
  trackEvent(ref, 'affiliate_click', {
    'product_id': productId,
    'partner': ?partner,
  });
}

void trackSearch(WidgetRef ref, String query) {
  if (query.trim().isEmpty) return;
  trackEvent(ref, 'search', {'query': query.trim()});
}

void trackSwipe(WidgetRef ref, String productId, String direction) {
  trackEvent(ref, 'swipe', {
    'product_id': productId,
    'direction': direction,
  });
}

void trackBlendCreated(WidgetRef ref, String blendId) {
  trackEvent(ref, 'blend_created', {'blend_id': blendId});
}

void trackBlendJoined(WidgetRef ref, String blendId) {
  trackEvent(ref, 'blend_joined', {'blend_id': blendId});
}

void trackBlendSwipe(WidgetRef ref, String blendId, String productId, String swipeType) {
  trackEvent(ref, 'blend_swipe', {
    'blend_id': blendId,
    'product_id': productId,
    'swipe_type': swipeType,
  });
}

void trackBlendResultsViewed(WidgetRef ref, String blendId, {int? fashionScore}) {
  trackEvent(ref, 'blend_results_viewed', {
    'blend_id': blendId,
    'fashion_score': fashionScore,
  });
}

void trackBlendSessionStarted(WidgetRef ref, String blendId, {int? memberCount}) {
  trackEvent(ref, 'blend_session_started', {
    'blend_id': blendId,
    'member_count': memberCount,
  });
}

void trackOnboardingComplete(WidgetRef ref, String persona) {
  trackEvent(ref, 'onboarding_complete', {'persona': persona});
}

void trackWardrobeAdd(WidgetRef ref, String productId, {String? category}) {
  trackEvent(ref, 'wardrobe_add', {
    'product_id': productId,
    'category': category,
  });
}

void trackWardrobeRemove(WidgetRef ref, int itemId, {String? category}) {
  trackEvent(ref, 'wardrobe_remove', {
    'item_id': itemId,
    'category': category,
  });
}

void trackUserFollow(WidgetRef ref, String targetUserId, {String? source}) {
  trackEvent(ref, 'user_follow', {
    'target_user_id': targetUserId,
    'source': source,
  });
}

void trackUserUnfollow(WidgetRef ref, String targetUserId, {String? source}) {
  trackEvent(ref, 'user_unfollow', {
    'target_user_id': targetUserId,
    'source': source,
  });
}
