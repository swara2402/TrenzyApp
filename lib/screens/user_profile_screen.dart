import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/auth_provider.dart' as auth_p;

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, this.uid});

  /// Firebase UID of the profile to view. When null, shows the signed-in user.
  final String? uid;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;
  bool _isOwnProfile = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(auth_p.authProvider).valueOrNull;
    if (user == null) {
      setState(() {
        _error = 'Not logged in';
        _isLoading = false;
      });
      return;
    }

    final targetUid = widget.uid ?? user.id;
    final isOwnProfile = widget.uid == null || widget.uid == user.id;
    if (!mounted) return;
    setState(() {
      _isOwnProfile = isOwnProfile;
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getUserProfile(targetUid);
      final userMap = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : data;

      bool isFollowing = false;
      if (!isOwnProfile) {
        try {
          isFollowing = await api.getFollowStatus(targetUid);
        } catch (_) {
          isFollowing = false;
        }
      }

      if (mounted) {
        setState(() {
          _profileData = userMap;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final current = _isFollowing;
    final targetUid = widget.uid;
    if (targetUid == null) return;

    setState(() => _isFollowing = !current);
    try {
      final api = ref.read(apiServiceProvider);
      if (current) {
        await api.unfollowUser(targetUid);
      } else {
        await api.followUser(targetUid);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = current);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update follow status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _profileData?['name'] as String? ??
        'User';
    final avatarUrl = _profileData?['avatarUrl'] as String? ??
        _profileData?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF16130B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16130B).withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFEAE1D4)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFFE9C349),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFFF2CA50)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2CA50)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFFD0C5AF))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _isLoading = true; _error = null; });
                          _loadProfile();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2CA50)),
                        child: const Text('Retry', style: TextStyle(color: Color(0xFF16130B))),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(userName, avatarUrl),
                      const SizedBox(height: 24),
                      _buildStats(),
                      const SizedBox(height: 24),
                      _buildTabs(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(String name, String? avatarUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF2D2A21),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFFF2CA50),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFFEAE1D4),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isOwnProfile) ...[
                ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2CA50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isFollowing ? 'Unfollow' : 'Follow',
                      style: const TextStyle(color: Color(0xFF16130B), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
              ],
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Messaging coming soon')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF2CA50)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Message', style: TextStyle(color: Color(0xFFF2CA50), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final postsCount = _profileData?['postsCount'] ?? 0;
    final followersCount = _profileData?['followersCount'] ?? 0;
    final followingCount = _profileData?['followingCount'] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Posts', postsCount.toString()),
        _buildStatItem('Followers', followersCount.toString()),
        _buildStatItem('Following', followingCount.toString()),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFEAE1D4),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE9C349),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final posts = _profileData?['posts'] as List<dynamic>? ?? [];
    final tagged = _profileData?['tagged'] as List<dynamic>? ?? [];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFFF2CA50),
            labelColor: Color(0xFFF2CA50),
            unselectedLabelColor: Color(0xFFEAE1D4),
            tabs: [Tab(text: 'Posts'), Tab(text: 'Tagged')],
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              children: [
                posts.isEmpty
                    ? const Center(
                        child: Text('No posts yet', style: TextStyle(color: Color(0xFF99907C))),
                      )
                    : _buildGrid(posts),
                tagged.isEmpty
                    ? const Center(
                        child: Text('No tagged posts', style: TextStyle(color: Color(0xFF99907C))),
                      )
                    : _buildGrid(tagged),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<dynamic> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        final imageUrl = item['imageUrl']?.toString() ?? item['image']?.toString() ?? '';

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF2D2A21),
                    child: const Icon(Icons.image, color: Color(0xFF99907C)),
                  ),
                )
              : Container(
                  color: const Color(0xFF2D2A21),
                  child: const Icon(Icons.image, color: Color(0xFF99907C)),
                ),
        );
      },
    );
  }
}
