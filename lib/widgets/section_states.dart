import 'package:flutter/material.dart';

import '../models/api_exception.dart';
import '../theme/glass_theme.dart';

/// Converts exceptions into friendly, human readable messages.
String friendlyError(Object error) {
  final text = error.toString();
  if (error is ApiException) {
    final code = error.statusCode;
    if (code != null && code >= 500) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }
    if (code != null && code == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (code != null && code == 404) {
      return 'Content not found or no longer available.';
    }
    if (text.toLowerCase().contains('network') ||
        text.toLowerCase().contains('connection') ||
        text.toLowerCase().contains('socket')) {
      return 'Looks like you\u2019re offline. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
  if (text.toLowerCase().contains('network') ||
      text.toLowerCase().contains('connection') ||
      text.toLowerCase().contains('socket')) {
    return 'Looks like you\u2019re offline. Check your connection and try again.';
  }
  if (text.toLowerCase().contains('timeout')) {
    return 'This is taking longer than usual. Try again in a moment.';
  }
  if (text.toLowerCase().contains('404') || text.toLowerCase().contains('not found')) {
    return 'Content not found or no longer available.';
  }
  return 'Something went wrong. Please try again.';
}

/// Compact inline error block for async sections.
///
/// Unlike a full-screen state, this is sized to flow inside a scroll view
/// (list item, section slot, etc.) so failures are always visible with a
/// Retry action — never silently swallowed with `SizedBox.shrink()`.
class ErrorSection extends StatelessWidget {
  const ErrorSection({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Couldn\'t load this',
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;
  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 52,
          height: compact ? 40 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.trenzyColors.crimson.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: compact ? 20 : 26, color: context.trenzyColors.crimson),
        ),
        SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GlassTypography.body(fontSize: compact ? 13 : 15, weight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg),
        ),
        SizedBox(height: 12),
        TapScale(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: context.trenzyColors.crimson.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(GlassRadius.button),
              border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 16, color: context.trenzyColors.crimson),
                SizedBox(width: 6),
                Text(
                  'Retry',
                  style: GlassTypography.body(fontSize: 12, weight: FontWeight.w700, color: context.trenzyColors.crimson),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: Center(child: content),
    );
  }
}

/// Sliver wrapper for [ErrorSection] so it can be dropped straight into a
/// `CustomScrollView`.
class ErrorSectionSliver extends StatelessWidget {
  const ErrorSectionSliver({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Couldn\'t load this',
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      sliver: SliverToBoxAdapter(
        child: ErrorSection(title: title, message: message, icon: icon, onRetry: onRetry, padding: EdgeInsets.zero),
      ),
    );
  }
}

/// Compact inline empty block for async sections.
///
/// Shows an icon, title, helpful subtitle and an optional action so an empty
/// state always gives the user a next step instead of a blank gap.
class EmptySection extends StatelessWidget {
  const EmptySection({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 30, color: context.trenzyColors.primary),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GlassTypography.body(fontSize: 16, weight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 16),
              TapScale(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(GlassRadius.button),
                    border: Border.all(color: context.trenzyColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    actionLabel!,
                    style: GlassTypography.body(fontSize: 12, weight: FontWeight.w700, color: context.trenzyColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sliver wrapper for [EmptySection].
class EmptySectionSliver extends StatelessWidget {
  const EmptySectionSliver({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      sliver: SliverToBoxAdapter(
        child: EmptySection(
          title: title,
          subtitle: subtitle,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
