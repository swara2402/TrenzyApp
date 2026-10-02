import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../router/app_router.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.onToggleTheme,
    this.leading,
    this.actions,
    this.showCart = true,
    this.onLeadingPressed,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showCart;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onLeadingPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartTotalItemsProvider);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(title),
      leading: leading ?? IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: onLeadingPressed ?? () => Scaffold.of(context).openDrawer(),
      ),
      actions: [
        if (showCart)
          Stack(
            alignment: Alignment.centerRight,
            children: [
              IconButton(
                icon: const Icon(Icons.bookmark_outline),
                onPressed: () => context.push(AppRoutes.cart),
              ),
              if (itemCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ...?actions,
      ],
    );
  }
}
