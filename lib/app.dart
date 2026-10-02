import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'router/app_router.dart';
import 'theme/glass_theme.dart';
import 'services/feature_flags.dart';
import 'services/api_service.dart';
import 'providers/theme_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/blend_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/feed_provider.dart';

class TrenzyApp extends ConsumerStatefulWidget {
  const TrenzyApp({super.key});

  @override
  ConsumerState<TrenzyApp> createState() => _TrenzyAppState();
}

class _TrenzyAppState extends ConsumerState<TrenzyApp> {
  late final GoRouter _router;
  final _authNotifier = ValueNotifier<bool>(FeatureFlags.devAuthBypass);
  final _onboardingCompleteNotifier = ValueNotifier<bool>(FeatureFlags.devAuthBypass);
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _router = createRouter(
      authNotifier: _authNotifier,
      onboardingCompleteNotifier: _onboardingCompleteNotifier,
      onToggleTheme: () => toggleTheme(ref),
    );
    ApiService.onSessionExpired = () {
      _authNotifier.value = false;
      _router.go(AppRoutes.login);
    };

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _authNotifier.value = user != null || FeatureFlags.devAuthBypass;
      if (FeatureFlags.devAuthBypass) {
        _onboardingCompleteNotifier.value = true;
      }
      // Invalidate all user-specific providers on logout
      if (user == null && !FeatureFlags.devAuthBypass) {
        ref.invalidate(cartProvider);
        ref.invalidate(wishlistProvider);
        ref.invalidate(wardrobeProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(blendNotifierProvider);
        ref.invalidate(friendProvider);
        ref.invalidate(userPreferencesProvider);
        ref.invalidate(feedProvider);
      }
    });



    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Consumer(
        builder: (context, ref, _) {
          final c = context.trenzyColors;
          return Scaffold(
            backgroundColor: c.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: c.crimson),
                    const SizedBox(height: 24),
                    DisplayText('Something went wrong', fontSize: 20),
                    const SizedBox(height: 12),
                    Text(
                      'Please try again or restart the app.',
                      style: GlassTypography.body(color: c.fg60),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GlowButton(
                      label: 'Go Back',
                      onTap: () {
                        _router.routerDelegate.navigatorKey.currentState?.pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    };
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authNotifier.dispose();
    _onboardingCompleteNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userPreferencesProvider, (prev, next) {
      _onboardingCompleteNotifier.value = next.onboardingCompleted;
    });

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Trenzy',
      themeMode: themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      routerConfig: _router,
      builder: (context, child) {
        return child ??
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_rounded, size: 64, color: context.trenzyColors.crimson),
                    const SizedBox(height: 16),
                    DisplayText('Blank screen', fontSize: 20),
                    const SizedBox(height: 8),
                    Text(
                      'GoRouter returned no widget for the current route.',
                      style: GlassTypography.body(color: context.trenzyColors.fg60),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GlowButton(
                      label: 'Go to Splash',
                      onTap: () => _router.go(AppRoutes.splash),
                    ),
                  ],
                ),
              ),
            );
      },
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TrenzyColors.dark.background,
      extensions: const [TrenzyColors.dark],
      colorScheme: ColorScheme.dark(
        primary: TrenzyColors.dark.primary,
        secondary: TrenzyColors.dark.emerald,
        surface: TrenzyColors.dark.background,
        onSurface: TrenzyColors.dark.foreground,
        error: TrenzyColors.dark.crimson,
      ),
      fontFamily: GlassTypography.bodyFont,
      textTheme: TextTheme(
        displayLarge: GlassTypography.display(fontSize: 40),
        displayMedium: GlassTypography.display(fontSize: 36),
        displaySmall: GlassTypography.display(fontSize: 32),
        headlineLarge: GlassTypography.display(fontSize: 32, weight: FontWeight.w700),
        headlineMedium: GlassTypography.display(fontSize: 28, weight: FontWeight.w700),
        headlineSmall: GlassTypography.display(fontSize: 24, weight: FontWeight.w700),
        titleLarge: GlassTypography.body(fontSize: 20, weight: FontWeight.w600),
        titleMedium: GlassTypography.body(fontSize: 16, weight: FontWeight.w600),
        titleSmall: GlassTypography.body(fontSize: 14, weight: FontWeight.w600),
        bodyLarge: GlassTypography.body(fontSize: 16),
        bodyMedium: GlassTypography.body(fontSize: 14),
        bodySmall: GlassTypography.body(fontSize: 12, color: GlassColors.mutedFg),
        labelLarge: GlassTypography.buttonLabel(fontSize: 14, color: GlassColors.foreground),
        labelMedium: GlassTypography.meta(fontSize: 12),
        labelSmall: GlassTypography.meta(fontSize: 10),
      )..apply(bodyColor: TrenzyColors.dark.foreground, displayColor: TrenzyColors.dark.foreground),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: TrenzyColors.dark.foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GlassTypography.display(fontSize: 20),
      ),
      cardColor: TrenzyColors.dark.glass,
      dividerColor: TrenzyColors.dark.fg20,
      iconTheme: IconThemeData(color: TrenzyColors.dark.foreground),
      cardTheme: CardThemeData(
        color: TrenzyColors.dark.glass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.card),
          side: BorderSide(color: TrenzyColors.dark.glassBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.dialog),
        ),
        backgroundColor: TrenzyColors.dark.glassDock,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TrenzyColors.dark.glassDock,
        contentTextStyle: GlassTypography.body(),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.dark.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.dark.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.dark.primary, width: 1.5),
        ),
        hintStyle: GlassTypography.body(color: TrenzyColors.dark.fg50),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TrenzyColors.dark.fg10,
        selectedColor: TrenzyColors.dark.primaryDim,
        labelStyle: GlassTypography.body(fontSize: 12),
        secondaryLabelStyle: GlassTypography.body(fontSize: 12, color: TrenzyColors.dark.primaryFg),
        side: BorderSide(color: TrenzyColors.dark.fg20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlassRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TrenzyColors.dark.primary,
          foregroundColor: TrenzyColors.dark.primaryFg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.button),
          ),
          textStyle: GlassTypography.buttonLabel(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TrenzyColors.dark.foreground,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: TrenzyColors.dark.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.button),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          minimumSize: const Size(0, 54),
          textStyle: GlassTypography.buttonLabel(color: TrenzyColors.dark.foreground),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TrenzyColors.light.background,
      extensions: const [TrenzyColors.light],
      colorScheme: ColorScheme.light(
        primary: TrenzyColors.light.primary,
        secondary: TrenzyColors.light.emerald,
        surface: TrenzyColors.light.background,
        onSurface: TrenzyColors.light.foreground,
        error: TrenzyColors.light.crimson,
      ),
      fontFamily: GlassTypography.bodyFont,
      textTheme: TextTheme(
        displayLarge: GlassTypography.display(fontSize: 40),
        displayMedium: GlassTypography.display(fontSize: 36),
        displaySmall: GlassTypography.display(fontSize: 32),
        headlineLarge: GlassTypography.display(fontSize: 32, weight: FontWeight.w700),
        headlineMedium: GlassTypography.display(fontSize: 28, weight: FontWeight.w700),
        headlineSmall: GlassTypography.display(fontSize: 24, weight: FontWeight.w700),
        titleLarge: GlassTypography.body(fontSize: 20, weight: FontWeight.w600),
        titleMedium: GlassTypography.body(fontSize: 16, weight: FontWeight.w600),
        titleSmall: GlassTypography.body(fontSize: 14, weight: FontWeight.w600),
        bodyLarge: GlassTypography.body(fontSize: 16),
        bodyMedium: GlassTypography.body(fontSize: 14),
        bodySmall: GlassTypography.body(fontSize: 12, color: TrenzyColors.light.mutedFg),
        labelLarge: GlassTypography.buttonLabel(fontSize: 14, color: TrenzyColors.light.foreground),
        labelMedium: GlassTypography.meta(fontSize: 12, color: TrenzyColors.light.fg50),
        labelSmall: GlassTypography.meta(fontSize: 10, color: TrenzyColors.light.fg50),
      )..apply(bodyColor: TrenzyColors.light.foreground, displayColor: TrenzyColors.light.foreground),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: TrenzyColors.light.foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GlassTypography.display(fontSize: 20),
      ),
      cardColor: TrenzyColors.light.glass,
      dividerColor: TrenzyColors.light.fg20,
      iconTheme: IconThemeData(color: TrenzyColors.light.foreground),
      cardTheme: CardThemeData(
        color: TrenzyColors.light.glass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.card),
          side: BorderSide(color: TrenzyColors.light.glassBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.dialog),
        ),
        backgroundColor: TrenzyColors.light.glassDock,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TrenzyColors.light.glassDock,
        contentTextStyle: GlassTypography.body(),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.light.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.light.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlassRadius.input),
          borderSide: BorderSide(color: TrenzyColors.light.primary, width: 1.5),
        ),
        hintStyle: GlassTypography.body(color: TrenzyColors.light.fg50),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TrenzyColors.light.fg10,
        selectedColor: TrenzyColors.light.primaryDim,
        labelStyle: GlassTypography.body(fontSize: 12),
        secondaryLabelStyle: GlassTypography.body(fontSize: 12, color: TrenzyColors.light.primaryFg),
        side: BorderSide(color: TrenzyColors.light.fg20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlassRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TrenzyColors.light.primary,
          foregroundColor: TrenzyColors.light.primaryFg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.button),
          ),
          textStyle: GlassTypography.buttonLabel(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TrenzyColors.light.foreground,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: TrenzyColors.light.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlassRadius.button),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          minimumSize: const Size(0, 54),
          textStyle: GlassTypography.buttonLabel(color: TrenzyColors.light.foreground),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
