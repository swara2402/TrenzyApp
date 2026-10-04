/// Offline and session expired state widgets
///
/// Shows when user loses connectivity or session expires.
/// Provides automatic retry mechanism and clear next steps.
library;

import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';

/// Full-screen offline indicator
/// 
/// Shows when no network connectivity is detected.
/// Automatically retries when connection is restored.
class OfflineWidget extends StatelessWidget {
  /// Callback when user manually triggers retry
  final VoidCallback onRetry;

  /// Custom message (defaults to standard offline message)
  final String? message;

  /// Show as inline alert instead of full screen
  final bool compact;

  const OfflineWidget({
    super.key,
    required this.onRetry,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 44 : 64,
          height: compact ? 44 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.trenzyColors.crimson.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.wifi_off_rounded,
            size: compact ? 24 : 32,
            color: context.trenzyColors.crimson,
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'You\'re Offline',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 14 : 18,
            weight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          message ?? 'Check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 12 : 14,
            color: context.trenzyColors.mutedFg,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        _RetryButton(onTap: onRetry),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: context.trenzyColors.surfaceContainer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      ),
    );
  }
}

/// Session expired widget with login redirect
/// 
/// Shows when Firebase session has expired and user needs to re-authenticate.
class SessionExpiredWidget extends StatelessWidget {
  /// Callback to redirect to login screen
  final VoidCallback onRelogin;

  /// Custom message (defaults to standard session expiry message)
  final String? message;

  /// Show as inline alert instead of full screen
  final bool compact;

  const SessionExpiredWidget({
    super.key,
    required this.onRelogin,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 44 : 64,
          height: compact ? 44 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.trenzyColors.crimson.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.lock_clock_rounded,
            size: compact ? 24 : 32,
            color: context.trenzyColors.crimson,
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'Session Expired',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 14 : 18,
            weight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          message ??
              'Your session has expired for security. Please sign in again.',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 12 : 14,
            color: context.trenzyColors.mutedFg,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        GestureDetector(
          onTap: onRelogin,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 20,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: context.trenzyColors.crimson,
              borderRadius: BorderRadius.circular(GlassRadius.button),
            ),
            child: Text(
              'Sign In Again',
              style: GlassTypography.body(
                fontSize: compact ? 12 : 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: context.trenzyColors.surfaceContainer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      ),
    );
  }
}

/// Network error widget for temporary connectivity issues
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final bool compact;

  const NetworkErrorWidget({
    super.key,
    required this.onRetry,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 44 : 64,
          height: compact ? 44 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.trenzyColors.crimson.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.cloud_off_rounded,
            size: compact ? 24 : 32,
            color: context.trenzyColors.crimson,
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'Connection Error',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 14 : 18,
            weight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          message ?? 'Unable to reach the server. Please check your connection.',
          textAlign: TextAlign.center,
          style: GlassTypography.body(
            fontSize: compact ? 12 : 14,
            color: context.trenzyColors.mutedFg,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        _RetryButton(onTap: onRetry),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: context.trenzyColors.surfaceContainer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.mutedFg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      ),
    );
  }
}

/// Reusable retry button component
class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: context.trenzyColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(GlassRadius.button),
          border: Border.all(
            color: context.trenzyColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: context.trenzyColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Try Again',
              style: GlassTypography.body(
                fontSize: 12,
                weight: FontWeight.w700,
                color: context.trenzyColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}