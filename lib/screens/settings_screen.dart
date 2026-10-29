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

  void _showHelpAndSupport(BuildContext context) {
    final colors = context.trenzyColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.graphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.mutedFg.withValues(alpha: .45), borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 22),
              DisplayText('How can we help?', fontSize: 23, weight: FontWeight.w700),
              const SizedBox(height: 6),
              Text('Quick answers for your Trenzy beta experience.', style: GlassTypography.body(color: colors.mutedFg)),
              const SizedBox(height: 18),
              _helpRow(context, Icons.person_outline, 'Profile & username', 'Edit your name, username and bio in Settings → Edit Profile. Friends can find you by username.'),
              _helpRow(context, Icons.auto_awesome_outlined, 'Personalize your feed', 'Update your favourite categories, styles and discovery preferences any time in Settings.'),
              _helpRow(context, Icons.favorite_border, 'Wishlist & Blend', 'Save products to your wishlist or create a Blend to decide with friends.'),
              _helpRow(context, Icons.bug_report_outlined, 'Something not working?', 'Send us a short description and, if possible, the screen where it happened.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _sendFeedback(context);
                  },
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Contact Trenzy Support'),
                  style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.background, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpRow(BuildContext context, IconData icon, String title, String detail) {
    final colors = context.trenzyColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: colors.primary, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GlassTypography.body(color: colors.foreground, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(detail, style: GlassTypography.body(color: colors.mutedFg, fontSize: 12, height: 1.4)),
          ])),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final colors = context.trenzyColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.graphite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 76, height: 76, decoration: BoxDecoration(gradient: GlassGradients.primary, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 38)),
              const SizedBox(height: 16),
              DisplayText('Trenzy', fontSize: 28, weight: FontWeight.w800),
              const SizedBox(height: 5),
              Text('Find your vibe. Build your style.', style: GlassTypography.body(color: colors.primary, weight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('A fashion discovery space where your inspiration, wardrobe, AI styling and friends come together — so finding your next favourite look feels more personal and more fun.', textAlign: TextAlign.center, style: GlassTypography.body(color: colors.mutedFg, height: 1.5)),
              const SizedBox(height: 18),
              Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: colors.background.withValues(alpha: .55), borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.glassBorder)), child: Column(children: [
                Text('Version 1.0.0 • Controlled Beta', style: GlassTypography.body(color: colors.foreground, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Made for discovering style together.', style: GlassTypography.body(color: colors.mutedFg, fontSize: 12)),
              ])),
            ],
          ),
        ),
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: DisplayText(
            'Change Password',
            fontSize: 20,
            weight: FontWeight.w600,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'ll email you a secure link to reset your password.',
                style: GlassTypography.body(
                  color: context.trenzyColors.mutedFg,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                focusNode: focusNode,
                enabled: email.isEmpty,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: GlassTypography.body(
                  color: context.trenzyColors.foreground,
                ),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GlassTypography.body(
                    color: context.trenzyColors.mutedFg,
                  ),
                  hintText: 'you@example.com',
                  filled: true,
                  fillColor: context.trenzyColors.glass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.trenzyColors.glassBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.trenzyColors.glassBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.trenzyColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GlassTypography.body(
                  color: context.trenzyColors.mutedFg,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                submitted = true;
                Navigator.of(ctx).pop(true);
              },
              child: Text(
                'Send Reset Link',
                style: GlassTypography.body(
                  color: context.trenzyColors.primary,
                ),
              ),
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

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: DisplayText(
          'Delete Account',
          fontSize: 20,
          weight: FontWeight.w600,
        ),
        content: Text(
          'This action is permanent. All your data, preferences, and activity will be erased. This cannot be undone.',
          style: GlassTypography.body(
            color: context.trenzyColors.mutedFg,
            fontSize: 14,
            height: 1.5,
          ),
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
              style: GlassTypography.body(
                color: context.trenzyColors.crimson,
                weight: FontWeight.w700,
              ),
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
                padding: const EdgeInsets.fromLTRB(
                  GlassSpacing.lg,
                  8,
                  GlassSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    GlassBackButton(onTap: () => context.pop()),
                    SizedBox(width: 8),
                    DisplayText(
                      'Settings',
                      fontSize: 24,
                      weight: FontWeight.w600,
                      color: context.trenzyColors.primary,
                    ),
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
                          backgroundColor: context.trenzyColors.primary
                              .withValues(alpha: 0.15),
                          backgroundImage: NetworkImage(user.avatarUrl),
                          child: null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  color: context.trenzyColors.foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: context.trenzyColors.mutedFg
                                      .withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.trenzyColors.mutedFg,
                          size: 20,
                        ),
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
                    onTap: () => context.push(AppRoutes.editProfile),
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
                    onTap: () => context.push('${AppRoutes.favoriteCategories}?source=settings'),
                  ),
                  _buildItem(
                    icon: Icons.style_outlined,
                    title: 'Preferred Styles',
                    onTap: () => context.push('${AppRoutes.preferredStyles}?source=settings'),
                  ),
                  _buildItem(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Discovery Preferences',
                    onTap: () => context.push('${AppRoutes.discoveryPreferences}?source=settings'),
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
                      style: GlassTypography.body(
                        fontSize: 13,
                        color: context.trenzyColors.mutedFg,
                      ),
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
                    onTap: () => _showHelpAndSupport(context),
                  ),
                  _buildItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    trailing: Text(
                      'v1.0.0-beta',
                      style: GlassTypography.body(
                        fontSize: 12,
                        color: context.trenzyColors.mutedFg.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    onTap: () => _showAbout(context),
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
                      border: Border.all(
                        color: context.trenzyColors.crimson.withValues(
                          alpha: 0.3,
                        ),
                      ),
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DisplayText(
            title,
            fontSize: 14,
            weight: FontWeight.w700,
            color: GlassColors.primary,
          ),
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
              child: Text(title, style: GlassTypography.body(fontSize: 15)),
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
