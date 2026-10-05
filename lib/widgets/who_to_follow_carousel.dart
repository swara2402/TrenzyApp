import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/providers/discover_providers.dart';
import 'package:trenzy/providers/follow_provider.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/models/user_model.dart';
import 'package:trenzy/analytics/events.dart';

/// A carousel showing suggested users to follow based on style compatibility.
class WhoToFollowCarousel extends ConsumerWidget {
  const WhoToFollowCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final currentUser = authAsync.valueOrNull;
    
    if (currentUser == null) return SizedBox.shrink();

    return Semantics(
      label: 'Who to follow section. People with similar style taste.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.trenzyColors.crimson, context.trenzyColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Who to Follow',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.trenzyColors.foreground,
                  ),
                ),
                Spacer(),
                Semantics(
                  label: 'See all suggested users',
                  button: true,
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.allCreators),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: context.trenzyColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'People with similar taste',
              style: TextStyle(
                fontSize: 12,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: _SuggestedUsersList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestedUsersList extends ConsumerWidget {
  const _SuggestedUsersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedUsersAsync = ref.watch(discoverTrendingCreatorsProvider);
    
    return suggestedUsersAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (_, _) => _buildEmptyState(context, 'Could not load suggestions'),
      data: (users) {
        if (users.isEmpty) {
          return _buildEmptyState(context, 'Discover style friends');
        }
        return Semantics(
          label: 'List of ${users.length} suggested users to follow',
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _SuggestedUserCard(user: user);
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Semantics(
      label: 'Loading suggested users',
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LoadingSkeletonShimmer(
            height: 140,
            width: 120,
            radius: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Semantics(
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 32,
              color: context.trenzyColors.mutedFg,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedUserCard extends ConsumerStatefulWidget {
  const _SuggestedUserCard({required this.user});

  final UserModel user;

  @override
  ConsumerState<_SuggestedUserCard> createState() => _SuggestedUserCardState();
}

class _SuggestedUserCardState extends ConsumerState<_SuggestedUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFollow() async {
    // Animate button press
    _controller.forward().then((_) {
      _controller.reverse();
    });
    
    final api = ref.read(apiServiceProvider);
    final targetUid = widget.user.id;
    final currentStatus = ref.read(followStatusProvider(targetUid));
    final isCurrentlyFollowing = currentStatus.valueOrNull ?? false;
    
    // Optimistic update - immediately update the UI
    ref.invalidate(followStatusProvider(targetUid));
    
    try {
      // Make the API call based on the optimistic state
      if (isCurrentlyFollowing) {
        await api.unfollowUser(targetUid);
        // Track unfollow event
        trackUserUnfollow(ref, targetUid, source: 'who_to_follow_carousel');
      } else {
        await api.followUser(targetUid);
        // Track follow event
        trackUserFollow(ref, targetUid, source: 'who_to_follow_carousel');
      }
      
      // Refresh the suggested users list to reflect changes
      ref.invalidate(discoverTrendingCreatorsProvider);
    } catch (e) {
      // Revert optimistic update on error
      ref.invalidate(followStatusProvider(targetUid));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing 
                ? 'Failed to unfollow. Please try again.'
                : 'Failed to follow. Please try again.',
            ),
            backgroundColor: context.trenzyColors.crimson,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _toggleFollow(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetUid = widget.user.id;
    final followStatusAsync = ref.watch(followStatusProvider(targetUid));
    final isFollowing = followStatusAsync.valueOrNull ?? false;
    
    // Calculate style match based on user data (simplified)
    final styleMatch = _calculateStyleMatch(widget.user);

    return Semantics(
      label: '${widget.user.name}. Style match: $styleMatch percent. ${isFollowing ? "Following" : "Not following"}.',
      button: true,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () => context.push(
            AppRoutes.userProfile,
            extra: widget.user.id,
          ),
          child: Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.trenzyColors.graphite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.trenzyColors.glassBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar with style match badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Semantics(
                      label: '${widget.user.name} profile picture',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getMatchColor(styleMatch).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: _buildAvatar(),
                      ),
                    ),
                    // Style match badge
                    if (styleMatch > 0)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Semantics(
                          label: 'Style match: $styleMatch percent',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getMatchColor(styleMatch),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: _getMatchColor(styleMatch).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              '$styleMatch%',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                // Name
                Semantics(
                  label: 'User name: ${widget.user.name}',
                  child: Text(
                    widget.user.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.trenzyColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 8),
                // Follow button
                Semantics(
                  label: isFollowing ? 'Unfollow ${widget.user.name}' : 'Follow ${widget.user.name}',
                  button: true,
                  child: GestureDetector(
                    onTap: _toggleFollow,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isFollowing ? null : GlassGradients.primary,
                        color: isFollowing ? context.trenzyColors.glass : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isFollowing
                            ? Border.all(color: context.trenzyColors.glassBorder)
                            : null,
                      ),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFollowing
                              ? context.trenzyColors.mutedFg
                              : context.trenzyColors.primaryFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final imageUrl = widget.user.avatarUrl;
    final name = widget.user.name;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            color: context.trenzyColors.glass,
            child: Icon(Icons.person, color: context.trenzyColors.mutedFg),
          ),
          errorWidget: (_, _, _) => _buildInitialsAvatar(initials),
        ),
      );
    }
    
    return _buildInitialsAvatar(initials);
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: context.trenzyColors.glass,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.trenzyColors.mutedFg,
          ),
        ),
      ),
    );
  }

  Color _getMatchColor(int match) {
    if (match >= 80) return context.trenzyColors.emerald;
    if (match >= 60) return context.trenzyColors.primary;
    return context.trenzyColors.mutedFg;
  }

  int _calculateStyleMatch(UserModel user) {
    // Simplified style match calculation
    // In production, this would come from the API
    final name = user.name;
    final hash = name.hashCode.abs();
    return 50 + (hash % 40); // Returns 50-89%
  }
}
