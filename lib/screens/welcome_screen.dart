import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    final size = MediaQuery.sizeOf(context);
    // Responsive sizing based on screen width
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 768 && size.width < 1024;
    final horizontalPadding = isDesktop ? size.width * 0.15 : 24.0;
    final headlineFontSize = isDesktop ? 64.0 : (isTablet ? 52.0 : 40.0);
    final bodyFontSize = isDesktop ? 18.0 : (isTablet ? 17.0 : 15.5);
    final brandFontSize = isDesktop ? 36.0 : (isTablet ? 32.0 : 28.0);
    final buttonHeight = isDesktop ? 64.0 : (isTablet ? 60.0 : 56.0);
    final spacing = isDesktop ? 48.0 : (isTablet ? 40.0 : 36.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Editorial Photography Layer (Quiet Luxury Aesthetic)
          Positioned.fill(
            child: Image.asset(
              'assets/editorial/welcome_editorial.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, -0.2),
              errorBuilder: (context, error, stackTrace) {
                // Fallback to warm rich gradient if image is unavailable
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.surfaceContainer,
                        colors.background,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Cinematic Warm Vignette & Espresso Fade
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0.75),
                    colors.background.withValues(alpha: 0.15),
                    colors.background.withValues(alpha: 0.40),
                    colors.background.withValues(alpha: 0.88),
                    colors.background,
                  ],
                  stops: const [0.0, 0.22, 0.45, 0.72, 1.0],
                ),
              ),
            ),
          ),

          // 3. Subtle Rose-Gold Ambient Light Leak (Restrained Luxury Glow)
          Positioned(
            left: -40,
            bottom: size.height * 0.18,
            width: size.width + 80,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.1, 0.2),
                    radius: 0.85,
                    colors: [
                      colors.primary.withValues(alpha: 0.09),
                      colors.primary.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. Content Structure
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Brand Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Brand Mark with Signature Rose-Gold Accent Dot
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Trenzy',
                                      style: TextStyle(
                                        fontFamily: GlassTypography.bodyFont,
                                        fontSize: brandFontSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: colors.foreground,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '.',
                                      style: TextStyle(
                                        fontFamily: GlassTypography.bodyFont,
                                        fontSize: brandFontSize + 4,
                                        fontWeight: FontWeight.w900,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Editorial Capsule Tag
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: colors.foreground.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(GlassRadius.pill),
                                          border: Border.all(
                                            color: colors.foreground.withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: colors.primary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: colors.primary.withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'AUTUMN / WINTER',
                                              style: TextStyle(
                                                fontFamily: GlassTypography.bodyFont,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.4,
                                                color: colors.foreground.withValues(alpha: 0.85),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isDesktop ? 160 : 120),

                          // Editorial Bottom Typography & Action Controls
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kicker Eyebrow with Rose-Gold Indicator
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(GlassRadius.pill),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainer.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(GlassRadius.pill),
                                        border: Border.all(
                                          color: colors.primary.withValues(alpha: 0.28),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: colors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'PERSONAL STYLING & CURATION',
                                            style: TextStyle(
                                              fontFamily: GlassTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.5,
                                              color: colors.foreground.withValues(alpha: 0.90),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Editorial Main Headline
                              Text(
                                'Dressed with\nintention.',
                                style: TextStyle(
                                  fontFamily: GlassTypography.bodyFont,
                                  fontSize: headlineFontSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.08,
                                  letterSpacing: -1.0,
                                  color: colors.foreground,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Editorial Subtitle (Warm Taupe)
                              Text(
                                'Curated silhouettes and daily edits, tailored to your aesthetic, taste, and wardrobe.',
                                style: TextStyle(
                                  fontFamily: GlassTypography.bodyFont,
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.48,
                                  letterSpacing: -0.1,
                                  color: colors.mutedFg,
                                ),
                              ),

                              SizedBox(height: spacing),

                              // High-Contrast Tactile Actions (The Real-App Formula)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Primary Action: Warm Alabaster Solid Pill with Espresso Text
                                  Semantics(
                                    button: true,
                                    label: 'Get started with Trenzy',
                                    hint: 'Opens account registration',
                                    child: TapScale(
                                      onTap: () => context.go(AppRoutes.signUp),
                                      child: Container(
                                      height: buttonHeight,
                                      decoration: BoxDecoration(
                                        color: colors.foreground,
                                        borderRadius: BorderRadius.circular(GlassRadius.pill),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.35),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.22),
                                            blurRadius: 30,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: TextStyle(
                                              fontFamily: GlassTypography.bodyFont,
                                              fontSize: isDesktop ? 18 : 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                              color: colors.background,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: colors.background,
                                          ),
                                        ],
                                      ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Secondary Action: Cashmere Frosted Glass Pill
                                  Semantics(
                                    button: true,
                                    label: 'Sign in to your account',
                                    hint: 'Opens sign in',
                                    child: TapScale(
                                      onTap: () => context.go(AppRoutes.login),
                                      child: ClipRRect(
                                      borderRadius: BorderRadius.circular(GlassRadius.pill),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                        child: Container(
                                          height: isDesktop ? 60 : (isTablet ? 56 : 52),
                                          decoration: BoxDecoration(
                                            color: colors.foreground.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(GlassRadius.pill),
                                            border: Border.all(
                                              color: colors.foreground.withValues(alpha: 0.16),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Sign in to your account',
                                            style: TextStyle(
                                              fontFamily: GlassTypography.bodyFont,
                                              fontSize: isDesktop ? 17 : 15,                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.1,
                                              color: colors.foreground.withValues(alpha: 0.90),
                                            ),
                                          ),
                                        ),
                                      ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}