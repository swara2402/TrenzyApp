import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

/// Account screen — surfaces the most important account actions inline and
/// links to SettingsScreen for the full management experience.
///
/// Previously this was a single-item stub. Full account management
/// (logout, delete account, preferences) lives in [SettingsScreen].
class AccountScreen extends ConsumerWidget {
  final VoidCallback onToggleTheme;

  const AccountScreen({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final authAsync = ref.watch(authProvider);
    final c = context.trenzyColors;

    final user = authAsync.valueOrNull;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GlassBackButton(),
        title: Text(
          'Account',
          style: GlassTypography.display(
            fontSize: 18,
            color: c.foreground,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── User identity card ─────────────────────────────────────────
          if (user != null)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: c.graphite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.glassBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: c.primary.withValues(alpha: 0.15),
                    child: Text(
                      (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                      style: GlassTypography.display(
                        fontSize: 22,
                        color: c.primary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: GlassTypography.body(
                            fontSize: 16,
                            color: c.foreground,
                            weight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? '',
                          style: GlassTypography.body(
                            fontSize: 13,
                            color: c.mutedFg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Appearance ────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          _AccountTile(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: '${isDark ? 'Dark' : 'Light'} Mode',
            subtitle: 'Switch between dark and light theme',
            trailing: Switch(
              value: isDark,
              onChanged: (_) => onToggleTheme(),
              activeThumbColor: c.primary,
            ),
            onTap: onToggleTheme,
          ),
          const SizedBox(height: 24),

          // ── Account management ────────────────────────────────────────
          _SectionHeader(label: 'Account'),
          _AccountTile(
            icon: Icons.settings_rounded,
            label: 'Settings',
            subtitle: 'Preferences, privacy, logout, and more',
            onTap: () => context.push(AppRoutes.settings),
          ),
          _AccountTile(
            icon: Icons.person_outline_rounded,
            label: 'View Profile',
            subtitle: 'Your posts, wardrobe, and following',
            onTap: () => context.push(AppRoutes.profile),
          ),
          _AccountTile(
            icon: Icons.shield_outlined,
            label: 'Privacy Policy',
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          _AccountTile(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: () => context.push(AppRoutes.termsOfService),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: GlassTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: context.trenzyColors.primary,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: c.graphite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.mutedFg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GlassTypography.body(
                      fontSize: 15,
                      color: c.foreground,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GlassTypography.body(
                        fontSize: 12,
                        color: c.mutedFg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, size: 18, color: c.mutedFg),
          ],
        ),
      ),
    );
  }
}
