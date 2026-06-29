import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_gradients.dart';

import 'services/api_service.dart';

class TrenzyApp extends StatefulWidget {
  const TrenzyApp({super.key});

  @override
  State<TrenzyApp> createState() => _TrenzyAppState();
}

class _TrenzyAppState extends State<TrenzyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter(onToggleTheme: _toggleTheme);
    ApiService.onSessionExpired = () {
      _router.go(AppRoutes.login);
    };
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Trenzy',

      themeMode: _themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),

      routerConfig: _router,

      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please try again or restart the app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        _router.routerDelegate.navigatorKey.currentState?.pop();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppGradients.dark : AppGradients.light,
          ),
          child:
              child ??
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Blank screen',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GoRouter returned no widget for the current route.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          _router.go(AppRoutes.splash);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Go to Splash'),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
}
