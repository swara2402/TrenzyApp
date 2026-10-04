import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/auth_provider.dart' as auth_p;
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/trenzy_colors.dart';

class DiscoverAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const DiscoverAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(auth_p.authProvider).valueOrNull;
    final avatarUrl = user?.avatarUrl;
    final userName = user?.name ?? 'U';

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: context.trenzyColors.surfaceContainer,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  userName[0].toUpperCase(),
                  style: TextStyle(
                    color: context.trenzyColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
      title: const Text('Discover'),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => context.push(AppRoutes.notifications),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
