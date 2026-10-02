import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cart_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

/// Decision List (cart) entry point with a live item-count badge.
///
/// The cart has no bottom-nav slot, so headers surface it directly —
/// without this, the Decision List is only reachable via toasts and
/// deep links, which users discover as a dead end.
class CartBadgeButton extends ConsumerWidget {
  const CartBadgeButton({super.key, this.iconSize = 22});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the cart so the badge updates the moment an item is added.
    final count = ref.watch(cartTotalItemsProvider);

    return IconButton(
      padding: EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(),
      tooltip: 'Decision List',
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: context.trenzyColors.primary,
        textColor: context.trenzyColors.primaryFg,
        label: Text('$count'),
        child: Icon(
          Icons.shopping_bag_outlined,
          size: iconSize,
          color: context.trenzyColors.mutedFg,
        ),
      ),
      onPressed: () => context.push(AppRoutes.cart),
    );
  }
}
