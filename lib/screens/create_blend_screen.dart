import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/models/friend.dart';
import 'package:trenzy/providers/friend_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/analytics/events.dart';
import 'package:trenzy/theme/trenzy_colors.dart';

final selectedFriendsProvider = StateProvider<List<Friend>>((ref) => []);

class CreateBlendScreen extends ConsumerStatefulWidget {
  const CreateBlendScreen({super.key});

  @override
  ConsumerState<CreateBlendScreen> createState() => _CreateBlendScreenState();
}

class _CreateBlendScreenState extends ConsumerState<CreateBlendScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _themeController = TextEditingController();

  String _formatCreateError(dynamic error) {
    final text = error.toString().toLowerCase();
    if (text.contains('name')) return 'Please enter a blend name.';
    if (text.contains('auth') || text.contains('logged in') || text.contains('login')) {
      return 'You need to be signed in to create a blend.';
    }
    if (text.contains('rate') || text.contains('limit') || text.contains('429')) {
      return 'Too many blends created just now. Please wait a moment and try again.';
    }
    if (text.contains('timeout') || text.contains('timed out') || text.contains('connection')) {
      return 'Couldn\u2019t reach the server. Check your connection and try again.';
    }
    return 'Could not create your blend. Please try again.';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _createBlend() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a blend name')),
      );
      return;
    }

    final selectedFriends = ref.read(selectedFriendsProvider);
    final blendNotifier = ref.read(blendNotifierProvider.notifier);

    try {
      final newBlend = await blendNotifier.createBlend(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        theme: _themeController.text.trim(),
      );

      if (newBlend != null && selectedFriends.isNotEmpty) {
        final inviterId = ref.read(authProvider).value?.id;
        if (inviterId == null) return;

        final friendIds = selectedFriends.map((friend) => friend.id).toList();
        await Future.wait(
          friendIds.map((friendId) =>
            ref.read(apiServiceProvider).inviteToBlend(
                  blendId: newBlend['id'],
                  inviterId: inviterId,
                  inviteeId: friendId.toString(),
                ),
          ),
        );
      }

      if (mounted && newBlend != null) {
        trackBlendCreated(ref, newBlend['id']?.toString() ?? '');
        context.go('${AppRoutes.blendLobby}?groupId=${newBlend['id']}');
      }
    } catch (e) {
      // Error is handled by the listener
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(blendNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_formatCreateError(error))),
          );
        },
      );
    });

    final blendState = ref.watch(blendNotifierProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: context.trenzyColors.background,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: context.trenzyColors.primary),
                  onPressed: () => context.go(AppRoutes.blendHub),
                ),
                title: Text(
                  'Create Blend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.trenzyColors.foreground,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CoverImage(),
                      const SizedBox(height: 32),
                      BlendNameInput(controller: _nameController),
                      const SizedBox(height: 24),
                      BlendDescriptionInput(controller: _descriptionController),
                      const SizedBox(height: 24),
                      BlendThemeInput(controller: _themeController),
                      const SizedBox(height: 32),
                      FriendSelector(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          BottomBar(
            onCreate: _createBlend,
            isLoading: blendState.isLoading,
          ),
        ],
      ),
    );
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: NetworkImage(
                'https://placehold.co/600x400/1a1a2e/666.png?text=Blend+Cover'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.photo_camera,
                      color: context.trenzyColors.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Change Cover'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlendNameInput extends StatelessWidget {
  final TextEditingController controller;
  const BlendNameInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blend Name'.toUpperCase(),
          style: TextStyle(
            color: context.trenzyColors.mutedFg,
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: TextStyle(color: context.trenzyColors.foreground, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'e.g., Winter Curation',
            hintStyle: TextStyle(color: context.trenzyColors.fg50),
            filled: true,
            fillColor: context.trenzyColors.graphite,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class BlendDescriptionInput extends StatelessWidget {
  final TextEditingController controller;
  const BlendDescriptionInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description'.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFA89F95), // cashmere
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: TextStyle(color: context.trenzyColors.foreground, fontSize: 16),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'A brief description of your blend...',
            hintStyle: TextStyle(color: context.trenzyColors.fg50),
            filled: true,
            fillColor: context.trenzyColors.graphite,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class BlendThemeInput extends StatelessWidget {
  final TextEditingController controller;
  const BlendThemeInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme (Optional)'.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFA89F95),
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          style: TextStyle(color: context.trenzyColors.foreground, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g., Goa Trip, Wedding, College Fest',
            hintStyle: TextStyle(color: context.trenzyColors.fg50),
            filled: true,
            fillColor: context.trenzyColors.graphite,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class FriendSelector extends ConsumerWidget {
  const FriendSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          style: TextStyle(color: context.trenzyColors.foreground),
          decoration: InputDecoration(
            hintText: 'Search friends by name or handle...',
            hintStyle: TextStyle(color: context.trenzyColors.fg50),
            prefixIcon: Icon(Icons.search, color: context.trenzyColors.fg50),
            filled: true,
            fillColor: context.trenzyColors.graphite,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Suggested Friends'.toUpperCase(),
          style: TextStyle(
            color: context.trenzyColors.mutedFg,
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 16),
        friendsAsync.when(
          data: (friendsState) => ListView.separated(
            itemCount: friendsState.friends.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final friend = friendsState.friends[index];
              return FriendCard(friend: friend);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Could not load friends right now.',
              style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class FriendCard extends ConsumerWidget {
  final Friend friend;

  const FriendCard({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFriends = ref.watch(selectedFriendsProvider);
    final isSelected = selectedFriends.contains(friend);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.trenzyColors.surfaceContainer.withAlpha(102),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(13)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(friend.avatarUrl!),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: TextStyle(
                      color: context.trenzyColors.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isSelected ? Icons.check : Icons.add,
                  color: isSelected ? context.trenzyColors.primary : context.trenzyColors.mutedFg,
                ),
                onPressed: () {
                  if (isSelected) {
                    ref.read(selectedFriendsProvider.notifier).state = [
                      ...selectedFriends..remove(friend)
                    ];
                  } else {
                    ref.read(selectedFriendsProvider.notifier).state = [
                      ...selectedFriends,
                      friend
                    ];
                  }
                },
                style: IconButton.styleFrom(
                  side: BorderSide(
                    color: isSelected
                        ? context.trenzyColors.primary.withAlpha(128)
                        : context.trenzyColors.fg15.withAlpha(77),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomBar extends StatelessWidget {
  final VoidCallback onCreate;
  final bool isLoading;
  const BottomBar({super.key, required this.onCreate, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            decoration: BoxDecoration(
              color: context.trenzyColors.background.withAlpha(230),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SelectedFriends(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onCreate,
                  icon: isLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Color(0xFF120F0E),
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Color(0xFF120F0E)),
                  label: Text(
                    isLoading ? 'Creating...' : 'Create Blend',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD79D8A), // rose-gold CTA
                    foregroundColor: const Color(0xFF120F0E), // espresso noir
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    shadowColor: const Color(0xFFD79D8A), // rose-gold glow
                    elevation: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelectedFriends extends ConsumerWidget {
  const SelectedFriends({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFriends = ref.watch(selectedFriendsProvider);

    return Row(
      children: [
        Text(
          'Selected'.toUpperCase(),
          style: TextStyle(
            color: context.trenzyColors.mutedFg,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: selectedFriends
                  .map((friend) => Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: FriendChip(
                          name: friend.name,
                          imageUrl: friend.avatarUrl ?? 'https://placehold.co/100x100/1a1a2e/666.png?text=?',
                          onDeleted: () {
                            ref.read(selectedFriendsProvider.notifier).state = [
                              ...selectedFriends..remove(friend)
                            ];
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class FriendChip extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onDeleted;

  const FriendChip(
      {super.key,
      required this.name,
      required this.imageUrl,
      required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
      ),
      label: Text(name),
      onDeleted: onDeleted,
      backgroundColor: context.trenzyColors.graphite,
      labelStyle: TextStyle(color: context.trenzyColors.foreground, fontSize: 12),
      deleteIconColor: context.trenzyColors.mutedFg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: const BorderSide(color: Colors.white10),
      ),
    );
  }
}