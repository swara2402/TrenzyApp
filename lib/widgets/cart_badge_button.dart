import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/wishlist_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

/// Saved inspiration entry point with a live item-count badge.
class CartBadgeButton extends ConsumerWidget {
  const CartBadgeButton({super.key, this.iconSize = 22});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      wishlistProvider.select((w) => w.valueOrNull?.productIds.length ?? 0),
    );

    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(),
      tooltip: 'Saved picks',
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: context.trenzyColors.primary,
        textColor: context.trenzyColors.primaryFg,
        label: Text('$count'),
        child: Icon(
          Icons.bookmark_outline_rounded,
          size: iconSize,
          color: context.trenzyColors.mutedFg,
        ),
      ),
      onPressed: () => context.push(AppRoutes.wishlist),
    );
  }
}
