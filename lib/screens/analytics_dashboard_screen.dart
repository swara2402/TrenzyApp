import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/services/feature_flags.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.trenzyColors.background.withValues(alpha: 0.8),
            pinned: true,
            elevation: 0,
            leading: GlassBackButton(),
            title: DisplayText(
              'Analytics Dashboard',
              fontSize: 20,
            ),
            actions: [
              // Firebase Console link
              Semantics(
                label: 'Open Firebase Analytics console',
                button: true,
                child: IconButton(
                  icon: Icon(Icons.open_in_new, color: context.trenzyColors.primary),
                  onPressed: () => _showFirebaseConsoleInfo(context),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analytics Status Card
                  _buildStatusCard(context, ref),
                  SizedBox(height: 24),
                  
                  // Quick Stats Section
                  _buildSectionHeader('Quick Stats'),
                  SizedBox(height: 12),
                  _buildQuickStatsGrid(context),
                  SizedBox(height: 24),
                  
                  // Tracked Events Section
                  _buildSectionHeader('Tracked Events'),
                  SizedBox(height: 12),
                  _buildEventsList(context),
                  SizedBox(height: 24),
                  
                  // Event Categories
                  _buildSectionHeader('Event Categories'),
                  SizedBox(height: 12),
                  _buildCategoryCards(context),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, WidgetRef ref) {
    final isEnabled = FeatureFlags.analyticsEnabled;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.trenzyColors.primary.withValues(alpha: 0.1),
            context.trenzyColors.emerald.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.trenzyColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEnabled 
                  ? context.trenzyColors.emerald.withValues(alpha: 0.15)
                  : context.trenzyColors.crimson.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEnabled ? Icons.check_circle : Icons.cancel,
              color: isEnabled ? context.trenzyColors.emerald : context.trenzyColors.crimson,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics ${isEnabled ? 'Active' : 'Disabled'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.trenzyColors.foreground,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isEnabled 
                      ? 'Events are being tracked to Firebase Analytics'
                      : 'Analytics tracking is currently disabled',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.trenzyColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        color: GlassColors.primary,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildQuickStatsGrid(BuildContext context) {
    final stats = [
      _StatItem('Total Events', '14', Icons.analytics_outlined),
      _StatItem('Blend Events', '5', Icons.group_work),
      _StatItem('User Events', '4', Icons.person_outline),
      _StatItem('Wardrobe Events', '2', Icons.checkroom),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(context, stat);
      },
    );
  }

  Widget _buildStatCard(BuildContext context, _StatItem stat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, color: context.trenzyColors.primary, size: 20),
          SizedBox(height: 8),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.trenzyColors.foreground,
            ),
          ),
          SizedBox(height: 2),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 11,
              color: context.trenzyColors.mutedFg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(BuildContext context) {
    final events = [
      _EventItem('product_view', 'Product viewed', Icons.visibility),
      _EventItem('product_save', 'Product saved', Icons.bookmark),
      _EventItem('search', 'Search performed', Icons.search),
      _EventItem('swipe', 'Swipe action', Icons.swipe),
      _EventItem('blend_created', 'Blend created', Icons.group_add),
      _EventItem('blend_joined', 'Blend joined', Icons.group),
      _EventItem('blend_swipe', 'Blend swipe', Icons.touch_app),
      _EventItem('blend_results_viewed', 'Results viewed', Icons.bar_chart),
      _EventItem('blend_session_started', 'Session started', Icons.play_arrow),
      _EventItem('user_follow', 'User followed', Icons.person_add),
      _EventItem('user_unfollow', 'User unfollowed', Icons.person_remove),
      _EventItem('onboarding_complete', 'Onboarding done', Icons.check_circle),
      _EventItem('wardrobe_add', 'Wardrobe item added', Icons.checkroom),
      _EventItem('wardrobe_remove', 'Wardrobe item removed', Icons.delete_outline),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;
          
          return _buildEventTile(context, event, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, _EventItem event, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: isLast ? null : BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.trenzyColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.trenzyColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon, color: context.trenzyColors.primary, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.trenzyColors.foreground,
                    fontFamily: 'Monospace',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.trenzyColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: context.trenzyColors.emerald,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCards(BuildContext context) {
    final categories = [
      _CategoryItem(
        'Product Events',
        'Track product views, saves, and interactions',
        Icons.shopping_bag_outlined,
        context.trenzyColors.primary,
      ),
      _CategoryItem(
        'Blend Events',
        'Monitor collaborative feature usage',
        Icons.group_work,
        context.trenzyColors.emerald,
      ),
      _CategoryItem(
        'User Events',
        'Follow/unfollow and onboarding tracking',
        Icons.person_outline,
        Colors.purple,
      ),
      _CategoryItem(
        'Discovery Events',
        'Search and swipe discovery analytics',
        Icons.explore,
        Colors.blue,
      ),
      _CategoryItem(
        'Wardrobe Events',
        'Track wardrobe add/remove actions',
        Icons.checkroom,
        Colors.teal,
      ),
    ];

    return Column(
      children: categories.map((category) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategoryCard(context, category),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(BuildContext context, _CategoryItem category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.trenzyColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.trenzyColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  category.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.trenzyColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.trenzyColors.mutedFg),
        ],
      ),
    );
  }

  void _showFirebaseConsoleInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        title: Text(
          'Firebase Analytics Console',
          style: TextStyle(color: context.trenzyColors.foreground),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'View detailed analytics data in the Firebase Console:',
              style: TextStyle(color: context.trenzyColors.mutedFg),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.trenzyColors.glass,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'console.firebase.google.com',
                style: TextStyle(
                  color: context.trenzyColors.primary,
                  fontFamily: 'Monospace',
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Features available:\n• Real-time event tracking\n• User demographics\n• Conversion funnels\n• Custom reports',
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: context.trenzyColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  _StatItem(this.label, this.value, this.icon);
}

class _EventItem {
  final String name;
  final String description;
  final IconData icon;

  _EventItem(this.name, this.description, this.icon);
}

class _CategoryItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _CategoryItem(this.title, this.subtitle, this.icon, this.color);
}
