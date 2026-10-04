import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../router/app_router.dart';
import '../providers/auth_provider.dart';
import '../providers/api_service_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/glass_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: context.trenzyColors.graphite,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@trenzy.app',
      queryParameters: {'subject': 'Trenzy Feedback'},
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showSnackBar(context, 'No email app available on this device.');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, 'No email app available on this device.');
      }
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider).valueOrNull;
    final email = auth?.email ?? '';
    final emailController = TextEditingController(text: email);
    final focusNode = FocusNode();
    var submitted = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.trenzyColors.graphite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: DisplayText('Change Password', fontSize: 20, weight: FontWeight.w600),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'ll email you a secure link to reset your password.',
                style: GlassTypography.body(color: context.trenzyColors.mutedFg),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                focusNode: focusNode,
                enabled: email.isEmpty,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: GlassTypography.body(color: context.trenzyColors.foreground),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GlassTypography.body(color: context.trenzyColors.mutedFg),
                  hintText: 'you@example.com',
                  filled: true,
                  fillColor: context.trenzyColors.glass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.trenzyColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.trenzyColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: GlassTypography.body(color: context.trenzyColors.mutedFg)),
            ),
            TextButton(
              onPressed: () {
                submitted = true;
                Navigator.of(ctx).pop(true);
              },
              child: Text('Send Reset Link', style: GlassTypography.body(color: context.trenzyColors.primary)),
            ),
          ],
        ),
      );

      if (!submitted) return;

      final targetEmail = emailController.text.trim();
      if (targetEmail.isEmpty || !targetEmail.contains('@')) {
        if (context.mounted) {
          _showSnackBar(context, 'Please enter a valid email address');
        }
        return;
      }

      await ref.read(apiServiceProvider).resetPassword(targetEmail);
      if (context.mounted) {
        _showSnackBar(context, 'Password reset link sent to $targetEmail');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, 'Could not send reset link. Please try again.');
      }
    } finally {
      focusNode.dispose();
      emailController.dispose();
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: DisplayText('Logout', fontSize: 20, weight: FontWeight.w600),
        content: Text(
          'Are you sure you want to log out?',
          style: GlassTypography.body(color: context.trenzyColors.mutedFg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GlassTypography.body(color: context.trenzyColors.mutedFg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Logout',
              style: GlassTypography.body(color: context.trenzyColors.crimson),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: DisplayText('Delete Account', fontSize: 20, weight: FontWeight.w600),
        content: Text(
          'This action is permanent. All your data, preferences, and activity will be erased. This cannot be undone.',
          style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GlassTypography.body(color: context.trenzyColors.mutedFg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GlassTypography.body(color: context.trenzyColors.crimson, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
      if (confirmed == true && context.mounted) {
        final success = await ref.read(authProvider.notifier).deleteAccount();
        if (success && context.mounted) {
          context.go(AppRoutes.login);
        } else if (context.mounted) {
          _showSnackBar(context, 'Error deleting account. Please try again.');
        }
      }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(GlassSpacing.lg, 8, GlassSpacing.lg, 0),
                child: Row(
                  children: [
                    GlassBackButton(onTap: () => context.pop()),
                    SizedBox(width: 8),
                    DisplayText('Settings', fontSize: 24, weight: FontWeight.w600, color: context.trenzyColors.primary),
                  ],
                ),
              ),
              SizedBox(height: 8),

              // ── Profile summary ───────────────────────────────────────
              if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassContainer(
                    radius: 16,
                    color: context.trenzyColors.graphite,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: context.trenzyColors.primary.withValues(alpha: 0.15),
                          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                                  style: TextStyle(color: context.trenzyColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(color: context.trenzyColors.foreground, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                user.email ?? '',
                                style: TextStyle(color: context.trenzyColors.mutedFg.withValues(alpha: 0.7), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.trenzyColors.mutedFg, size: 20),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 24),

              // ── Account section ───────────────────────────────────────
              _buildSection(
                title: 'Account',
                children: [
                  _buildItem(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () => context.push(AppRoutes.userProfile),
                  ),
                  _buildItem(
                    icon: Icons.people_outline,
                    title: 'Friends',
                    onTap: () => context.push(AppRoutes.friends),
                  ),
                  _buildItem(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () => _changePassword(context, ref),
                  ),
                  _buildItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Preferences section ───────────────────────────────────
              _buildSection(
                title: 'Preferences',
                children: [
                  _buildItem(
                    icon: Icons.category_outlined,
                    title: 'Favorite Categories',
                    onTap: () => context.go(AppRoutes.favoriteCategories),
                  ),
                  _buildItem(
                    icon: Icons.style_outlined,
                    title: 'Preferred Styles',
                    onTap: () => context.go(AppRoutes.preferredStyles),
                  ),
                  _buildItem(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Discovery Preferences',
                    onTap: () => context.go(AppRoutes.discoveryPreferences),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Appearance section ────────────────────────────────────
              _buildSection(
                title: 'Appearance',
                children: [
                  _buildItem(
                    icon: Icons.dark_mode_outlined,
                    title: 'Theme',
                    trailing: Text(
                      ref.watch(isDarkModeProvider) ? 'Dark' : 'Light',
                      style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg),
                    ),
                    onTap: () => toggleTheme(ref),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Privacy & Security ────────────────────────────────────
              _buildSection(
                title: 'Privacy & Security',
                children: [
                  _buildItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => context.push(AppRoutes.privacyPolicy),
                  ),
                  _buildItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => context.push(AppRoutes.termsOfService),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Support section ───────────────────────────────────────
              _buildSection(
                title: 'Support',
                children: [
                  _buildItem(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    onTap: () => _sendFeedback(context),
                  ),
                  _buildItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => _showSnackBar(context, 'Help & Support coming soon'),
                  ),
                  _buildItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    trailing: Text(
                      'v1.0.0-beta',
                      style: GlassTypography.body(fontSize: 12, color: context.trenzyColors.mutedFg.withValues(alpha: 0.5)),
                    ),
                    onTap: () => _showSnackBar(context, 'Trenzy v1.0.0-beta'),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Developer section ─────────────────────────────────────
              _buildSection(
                title: 'Developer',
                children: [
                  _buildItem(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics Dashboard',
                    onTap: () => context.push(AppRoutes.analyticsDashboard),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // ── Logout button ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlowButton(
                  label: 'Logout',
                  onTap: () => _confirmLogout(context, ref),
                  width: double.infinity,
                ),
              ),
              SizedBox(height: 12),

              // ── Delete account ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _confirmDeleteAccount(context, ref),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(GlassRadius.button),
                      border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        'Delete Account',
                        style: GlassTypography.body(
                          color: context.trenzyColors.crimson,
                          weight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DisplayText(title, fontSize: 14, weight: FontWeight.w700, color: GlassColors.primary),
          SizedBox(height: 12),
          GlassContainer(
            radius: 16,
            color: GlassColors.graphite,
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: GlassColors.glassBorder)),
        ),
        child: Row(
          children: [
            Icon(icon, color: GlassColors.foreground, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GlassTypography.body(fontSize: 15),
              ),
            ),
            ?trailing,
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: GlassColors.mutedFg, size: 14),
          ],
        ),
      ),
    );
  }
}