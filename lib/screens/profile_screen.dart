import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/wardrobe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _handleFromName(String name) {
    return '@${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: authAsync.when(
          data: (user) => Text(
            user?.name ?? 'Profile',
            style: TextStyle(
              color: context.trenzyColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Text(
            'Profile',
            style: TextStyle(
              color: context.trenzyColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: context.trenzyColors.primary),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: authAsync.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.trenzyColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.trenzyColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: context.trenzyColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Sign in to view your profile',
                    style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 16),
                  ),
                  SizedBox(height: GlassSpacing.md),
                  GlowButton(
                    label: 'Sign In',
                    width: 160,
                    height: 48,
                    onTap: () => context.push(AppRoutes.login),
                  ),
                ],
              ),
            );
          }
          return _buildProfileContent(user);
        },
        loading: () => Center(
          child: LoadingSkeletonShimmer(height: 400, radius: 20),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(GlassSpacing.lg),
          child: Center(
            child: Text(
              'Could not load profile.',
              style: TextStyle(color: context.trenzyColors.crimson, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserModel user) {
    final wardrobeAsync = ref.watch(wardrobeProvider);
    final outfitsAsync = ref.watch(outfitsProvider);
    final personaAsync = ref.watch(personaProvider);
    final postsAsync = ref.watch(userPostsProvider(user.id));
    final followersAsync = ref.watch(followersProvider);
    final followingAsync = ref.watch(followingProvider);
    final wardrobeCount = wardrobeAsync.valueOrNull?.items.length ?? 0;
    final outfitsCount = outfitsAsync.valueOrNull?.length ?? 0;
    final postsCount = postsAsync.valueOrNull?.length ?? 0;
    final followersCount = followersAsync.valueOrNull?.length ?? 0;
    final followingCount = followingAsync.valueOrNull?.length ?? 0;
    final persona = personaAsync.valueOrNull;

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: GlassSpacing.lg),
          _buildProfileHeader(user),
          SizedBox(height: GlassSpacing.xl),
          _buildStatsRow(postsCount, followersCount, followingCount, wardrobeCount, outfitsCount),
          SizedBox(height: GlassSpacing.xl),
          _buildActionButtons(user),
          SizedBox(height: GlassSpacing.xl),
          _buildStylePersonaCard(persona),
          SizedBox(height: GlassSpacing.xl),
          _buildTabBar(),
          _buildTabContent(
            postsAsync,
            wardrobeAsync.when(
              data: (state) => AsyncValue.data(state.items),
              loading: () => const AsyncValue.loading(),
              error: (e, st) => AsyncValue.error(e, st),
            ),
            outfitsAsync,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final personaName = ref.watch(personaProvider).valueOrNull?.name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
      child: Column(
        children: [
          // Avatar with gradient ring
          Container(
            width: 148,
            height: 148,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.trenzyColors.primary,
                  context.trenzyColors.emerald,
                  context.trenzyColors.primary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.trenzyColors.primary.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: user.avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.avatarUrl,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _avatarFallback(),
                      errorWidget: (_, _, _) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          SizedBox(height: GlassSpacing.md),
          Text(
            user.name,
            style: TextStyle(
              color: context.trenzyColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _handleFromName(user.name),
            style: TextStyle(
              color: context.trenzyColors.mutedFg,
              fontSize: 15,
            ),
          ),
          SizedBox(height: GlassSpacing.sm),
          if (personaName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.trenzyColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GlassRadius.chip),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'Style: $personaName',
                style: TextStyle(
                  color: context.trenzyColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int postsCount, int followersCount, int followingCount, int wardrobeCount, int outfitsCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: BorderRadius.circular(GlassRadius.panel),
          border: Border.all(
            color: context.trenzyColors.glassBorder,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              _buildStatItem(Icons.article_outlined, 'Posts', '$postsCount'),
              _buildVerticalDivider(),
              _buildStatItem(Icons.people_outline_rounded, 'Followers', '$followersCount'),
              _buildVerticalDivider(),
              _buildStatItem(Icons.person_add_outlined, 'Following', '$followingCount'),
              _buildVerticalDivider(),
              _buildStatItem(Icons.checkroom_outlined, 'Wardrobe', '$wardrobeCount'),
              _buildVerticalDivider(),
              _buildStatItem(Icons.style_outlined, 'Outfits', '$outfitsCount'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: context.trenzyColors.glassBorder,
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Icon(icon, color: context.trenzyColors.primary, size: 18),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: context.trenzyColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.trenzyColors.mutedFg,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 140,
      height: 140,
      color: context.trenzyColors.graphite,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 56,
        color: context.trenzyColors.mutedFg,
      ),
    );
  }

  Widget _buildActionButtons(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: GlowButton(
              label: 'Edit Profile',
              height: 46,
              onTap: () => context.push(AppRoutes.settings),
            ),
          ),
          SizedBox(width: GlassSpacing.sm),
          Expanded(
            child: GlowButton(
              label: 'Friends',
              height: 46,
              onTap: () => context.push(AppRoutes.friends),
            ),
          ),
          SizedBox(width: GlassSpacing.sm),
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              border: Border.all(
                color: context.trenzyColors.primary.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(GlassRadius.button),
            ),
            child: IconButton(
              icon: Icon(Icons.share_rounded, color: context.trenzyColors.primary),
              onPressed: () => _shareProfile(context, user),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareProfile(BuildContext context, UserModel user) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out ${user.name} (${_handleFromName(user.name)}) on Trenzy — '
              'the app where friends blend their style to decide what to buy together.',
          subject: '${user.name} on Trenzy',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the share sheet.')),
        );
      }
    }
  }

  Widget _buildStylePersonaCard(StylePersona? persona) {
    final name = persona?.name ?? 'Urban Minimalist';
    final description = persona?.description ?? 'Discover your unique style profile';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(GlassSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.trenzyColors.graphite,
              context.trenzyColors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(GlassRadius.card),
          border: Border.all(
            color: context.trenzyColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: context.trenzyColors.primary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'YOUR STYLE PERSONA',
                    style: TextStyle(
                      color: context.trenzyColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                color: context.trenzyColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: GlassSpacing.sm),
            Text(
              description,
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: GlassSpacing.md),
            GestureDetector(
              onTap: () => context.push(AppRoutes.persona),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.trenzyColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.trenzyColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: context.trenzyColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'View Style DNA',
                      style: TextStyle(
                        color: context.trenzyColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: context.trenzyColors.primary,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(GlassRadius.panel),
        border: Border.all(
          color: context.trenzyColors.glassBorder,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.trenzyColors.primary.withValues(alpha: 0.2),
              context.trenzyColors.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(GlassRadius.panel),
          border: Border.all(
            color: context.trenzyColors.primary.withValues(alpha: 0.3),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: context.trenzyColors.primary,
        unselectedLabelColor: context.trenzyColors.mutedFg,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.checkroom_outlined, size: 18), text: 'Wardrobe'),
          Tab(icon: Icon(Icons.style_outlined, size: 18), text: 'Outfits'),
          Tab(icon: Icon(Icons.article_outlined, size: 18), text: 'Posts'),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    AsyncValue<List<Post>> postsAsync,
    AsyncValue<List<WardrobeItem>> wardrobeAsync,
    AsyncValue<List<Outfit>> outfitsAsync,
  ) {
    return SizedBox(
      height: 500,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildWardrobeGrid(wardrobeAsync),
          _buildOutfitsGrid(outfitsAsync),
          _buildPostsGrid(postsAsync),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(AsyncValue<List<Post>> postsAsync) {
    return postsAsync.when(
      loading: () => Center(child: LoadingSkeletonShimmer(height: 200, radius: 12)),
      error: (e, _) => Center(child: Text('Could not load posts', style: TextStyle(color: context.trenzyColors.mutedFg))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 40,
                  color: context.trenzyColors.mutedFg.withValues(alpha: 0.4),
                ),
                SizedBox(height: 12),
                Text(
                  'No posts yet',
                  style: TextStyle(color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(GlassSpacing.md),
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Container(
              decoration: BoxDecoration(
                color: context.trenzyColors.graphite,
                borderRadius: BorderRadius.circular(GlassRadius.card),
                border: Border.all(color: context.trenzyColors.glassBorder),
                image: DecorationImage(
                        image: CachedNetworkImageProvider(post.attachment),
                        fit: BoxFit.cover,
                      ),
              ),
              child: null,
            );
          },
        );
      },
    );
  }

  Widget _buildWardrobeGrid(AsyncValue<List<WardrobeItem>> wardrobeAsync) {
    return wardrobeAsync.when(
      loading: () => Center(child: LoadingSkeletonShimmer(height: 200, radius: 12)),
      error: (e, _) => Center(child: Text('Could not load wardrobe', style: TextStyle(color: context.trenzyColors.mutedFg))),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checkroom_outlined, size: 40, color: context.trenzyColors.mutedFg.withValues(alpha: 0.4)),
                SizedBox(height: 12),
                Text(
                  'Wardrobe is empty',
                  style: TextStyle(color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(GlassSpacing.md),
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              decoration: BoxDecoration(
                color: context.trenzyColors.graphite,
                borderRadius: BorderRadius.circular(GlassRadius.card),
                border: Border.all(
                  color: context.trenzyColors.glassBorder,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.trenzyColors.background,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(GlassRadius.card),
                        ),
                      ),
                      child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassRadius.card)),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: context.trenzyColors.graphite),
                                errorWidget: (_, _, _) => Icon(Icons.checkroom_outlined, color: context.trenzyColors.mutedFg),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GlassSpacing.sm,
                      vertical: 8,
                    ),
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOutfitsGrid(AsyncValue<List<Outfit>> outfitsAsync) {
    return outfitsAsync.when(
      loading: () => Center(child: LoadingSkeletonShimmer(height: 200, radius: 12)),
      error: (e, _) => Center(child: Text('Could not load outfits', style: TextStyle(color: context.trenzyColors.mutedFg))),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_outlined, size: 40, color: context.trenzyColors.mutedFg.withValues(alpha: 0.4)),
                SizedBox(height: 12),
                Text(
                  'No outfits yet',
                  style: TextStyle(color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(GlassSpacing.md),
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final outfit = items[index];
            return Container(
              decoration: BoxDecoration(
                color: context.trenzyColors.graphite,
                borderRadius: BorderRadius.circular(GlassRadius.card),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style_outlined,
                    color: context.trenzyColors.primary.withValues(alpha: 0.6),
                    size: 32,
                  ),
                  SizedBox(height: GlassSpacing.sm),
                  Text(
                    outfit.name,
                    style: TextStyle(
                      color: context.trenzyColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${outfit.items.length} items',
                    style: TextStyle(
                      color: context.trenzyColors.mutedFg,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}