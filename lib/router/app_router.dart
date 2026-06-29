import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/decision_flow.dart';
import '../screens/account_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/verify_email_screen.dart';

import '../screens/decision_screen.dart';

import '../screens/discover_screen.dart';
import '../screens/search_screen.dart';
import '../screens/input_screen.dart';
import '../screens/suggestions_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';

import '../screens/categories_screen.dart';
import '../screens/trends_screen.dart';

import '../screens/product_details_screen.dart';
import '../screens/history_screen.dart';

import '../screens/wishlist_screen.dart';

import '../screens/blend_hub_screen.dart';
import '../screens/blend_lobby_screen.dart';
import '../screens/blend_swipe_screen.dart';
import '../screens/blend_results_screen.dart';
import '../screens/blend_chat_screen.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_shell.dart';

class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const input = '/input';
  static const search = '/search';
  static const suggestions = '/suggestions';
  static const social = '/social';
  static const decision = '/decision';
  static const account = '/account';
  static const profile = '/profile';

  static const login = '/login';

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const categories = '/categories';
  static const trends = '/trends';
  static const productDetails = '/product-details';

  static const wishlist = '/wishlist';
  static const history = '/history';

  static const blendHub = '/blend';

  static const blendLobby = '/blend/lobby';
  static const blendSwipe = '/blend/swipe';
  static const blendResults = '/blend/results';
  static const blendChat = '/blend/chat';

  static const verifyEmail = '/verify-email';
}

class ProductDetailsRouteExtra {
  const ProductDetailsRouteExtra({required this.productId});

  final String productId;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// v1.0 Production Page Transition — Frozen Specification
/// Every screen: Fade + Slide (0, 0.03) → (0, 0)
/// Duration: 320ms
Page<dynamic> _springPage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  Duration? duration,
}) {
  final transitionDuration = duration ?? AppDurations.page;

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // v1.0: Standard easeOutCubic curve
      final curve = CurvedAnimation(
        parent: animation,
        curve: AppCurves.easeOutCubic,
      );

      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

GoRouter buildAppRouter({required VoidCallback onToggleTheme}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),

    redirect: (context, state) {
      if (state.uri.path == AppRoutes.root) {
        return AppRoutes.splash;
      }

      final user = FirebaseAuth.instance.currentUser;
      final isLoggingIn = state.uri.path == AppRoutes.login;
      final isOnboarding = state.uri.path == AppRoutes.onboarding;
      final isSplash = state.uri.path == AppRoutes.splash;
      final isVerifyEmail = state.uri.path == AppRoutes.verifyEmail;

      final isPublicRoute = isLoggingIn || isOnboarding || isSplash;

      if (user == null) {
        if (!isPublicRoute) {
          return AppRoutes.onboarding;
        }
        return null;
      }

      final isEmailPassword = user.providerData.any(
        (info) => info.providerId == 'password',
      );
      if (isEmailPassword && !user.emailVerified) {
        if (!isVerifyEmail && !isPublicRoute) {
          return AppRoutes.verifyEmail;
        }
        return null;
      }

      if (isPublicRoute || isVerifyEmail) {
        if (isSplash) return null;
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // ── Shell routes (show bottom nav) ─────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(currentLocation: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => _springPage(
              context,
              state,
              DiscoverScreen(onToggleTheme: onToggleTheme),
            ),
          ),
          GoRoute(
            path: AppRoutes.blendHub,
            pageBuilder: (context, state) => _springPage(
              context,
              state,
              BlendHubScreen(onToggleTheme: onToggleTheme),
            ),
          ),
          // Social Rooms tab removed for beta (founder scoped out)
          GoRoute(
            path: AppRoutes.wishlist,
            pageBuilder: (context, state) => _springPage(
              context,
              state,
              WishlistScreen(onToggleTheme: onToggleTheme),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => _springPage(
              context,
              state,
              AccountScreen(onToggleTheme: onToggleTheme),
            ),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _springPage(context, state, SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _springPage(
          context,
          state,
          OnboardingScreen(onToggleTheme: onToggleTheme),
        ),
      ),
      GoRoute(
        path: AppRoutes.categories,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _springPage(
          context,
          state,
          CategoriesScreen(onToggleTheme: onToggleTheme),
        ),
      ),
      GoRoute(
        path: AppRoutes.trends,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _springPage(context, state, const TrendsScreen()),
      ),
      GoRoute(
        path: AppRoutes.productDetails,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final details = extra is ProductDetailsRouteExtra ? extra : null;

          if (details == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }

          return _springPage(
            context,
            state,
            ProductDetailsScreen(
              onToggleTheme: onToggleTheme,
              productId: details.productId,
            ),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.history,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _springPage(
          context,
          state,
          HistoryScreen(onToggleTheme: onToggleTheme),
        ),
      ),

      GoRoute(
        path: AppRoutes.input,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _springPage(
          context,
          state,
          IntentInputScreen(onToggleTheme: onToggleTheme),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final initialQuery = state.uri.queryParameters['q'];
          final initialCategory = state.uri.queryParameters['category'];
          return _springPage(
            context,
            state,
            SearchScreen(
              onToggleTheme: onToggleTheme,
              initialQuery: initialQuery,
              initialCategory: initialCategory,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.suggestions,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final suggestionsExtra = extra is SuggestionsRouteExtra
              ? extra
              : null;

          if (suggestionsExtra == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }

          return _springPage(
            context,
            state,
            SuggestionsScreen(
              onToggleTheme: onToggleTheme,
              query: suggestionsExtra.query,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return _springPage(
            context,
            state,
            AuthScreen(onToggleTheme: onToggleTheme, initialMode: mode),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _springPage(
          context,
          state,
          VerifyEmailScreen(onToggleTheme: onToggleTheme),
        ),
      ),

      GoRoute(
        path: AppRoutes.blendLobby,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.extra?.toString();
          if (groupId == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }
          return _springPage(
            context,
            state,
            BlendLobbyScreen(onToggleTheme: onToggleTheme, groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendSwipe,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.extra?.toString();
          if (groupId == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }
          return _springPage(
            context,
            state,
            BlendSwipeScreen(onToggleTheme: onToggleTheme, groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendResults,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.extra?.toString();
          if (groupId == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }
          return _springPage(
            context,
            state,
            BlendResultsScreen(onToggleTheme: onToggleTheme, groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendChat,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.extra?.toString();
          if (groupId == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }
          return _springPage(
            context,
            state,
            BlendChatScreen(onToggleTheme: onToggleTheme, groupId: groupId),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.decision,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final decisionExtra = extra is DecisionRouteExtra ? extra : null;

          if (decisionExtra == null) {
            return _springPage(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }

          return _springPage(
            context,
            state,
            DecisionScreen(
              onToggleTheme: onToggleTheme,
              query: decisionExtra.query,
              selectedOptions: decisionExtra.selectedOptions
                  .map((o) => o.product)
                  .toList(),
              reactions: const [],
            ),
          );
        },
      ),
    ],
  );
}

class _MissingRouteExtraWidget extends StatelessWidget {
  const _MissingRouteExtraWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missing data')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Go to Home'),
        ),
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
