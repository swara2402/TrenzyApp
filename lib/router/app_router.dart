import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';

import '../screens/inspo_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/closet_screen.dart';
import '../screens/home_screen.dart';
import '../screens/trends_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/blend_hub_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/all_creators_screen.dart';
import '../screens/search_screen.dart';
import '../screens/login_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/age_verification_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/favorite_categories_screen.dart';
import '../screens/discovery_preferences_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/blend_lobby_screen.dart';
import '../screens/blend_swipe_screen.dart';
import '../screens/blend_results_screen.dart';
import '../screens/blend_chat_screen.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/outfit_builder_screen.dart';
import '../screens/persona_screen.dart';
import '../screens/ai_stylist_screen.dart';
import '../screens/ai_style_dna_screen.dart';
import '../screens/decision_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/add_item_screen.dart';
import '../screens/join_blend_screen.dart';
import '../screens/preferred_styles_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/swipe_discovery_screen.dart';
import '../screens/create_blend_screen.dart';
import '../screens/blend_dashboard_screen.dart';
import '../screens/shared_wishlist_screen.dart';
import '../screens/moodboard_screen.dart';
import '../screens/edit_clothing_screen.dart'; // Import EditClothingScreen
import '../models/wardrobe_model.dart'; // Import WardrobeItem
import '../models/decision_flow.dart' as decision_flow;

import '../screens/terms_of_service_screen.dart';
import '../screens/analytics_dashboard_screen.dart';
import '../screens/account_screen.dart';
import '../screens/friends_screen.dart';
import '../widgets/glass_app_shell.dart';
import '../theme/glass_theme.dart';

class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const search = '/search';
  static const decision = '/decision';
  static const account = '/account';
  static const profile = '/profile';
  static const inspo = '/inspo';

  static const login = '/login';
  static const signUp = '/sign-up';
  static const ageVerification = '/age-verification';
  static const forgotPassword = '/forgot-password';
  static const favoriteBrands = '/favorite-brands';
  static const favoriteCategories = '/favorite-categories';
  static const favoriteColors = '/favorite-colors';
  static const preferredBudget = '/preferred-budget';
  static const shoppingPriorities = '/shopping-priorities';
  static const discoverPreferences = '/discover-preferences';

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const categories = '/categories';
  static const trends = '/trends';
  static const productDetails = '/product-details';

  /// Location for a product's details page. The id is carried as a query
  /// parameter so the browser URL is shareable and survives a refresh —
  /// `extra` alone leaves the URL identical to the previous page.
  static String productDetailsFor(String productId) =>
      '$productDetails?productId=${Uri.encodeComponent(productId)}';

  static String firstIncompleteOnboardingRoute({
    Map<String, dynamic>? preferences,
    String source = 'onboarding',
  }) {
    final step = preferences?['onboarding_step'];
    final currentStep = step is int ? step : int.tryParse(step?.toString() ?? '') ?? 0;
    switch (currentStep) {
      case 0:
        return onboarding;
      case 1:
        return '$favoriteCategories?source=$source';
      case 2:
        return '$preferredStyles?source=$source';
      case 3:
        return '$discoveryPreferences?source=$source';
      case 4:
        return persona;
      default:
        return home;
    }
  }

  static String routeFromPreferencesResponse(
    Map<String, dynamic> response, {
    String source = 'onboarding',
  }) {
    final rawPreferences = response['preferences'];
    final preferences = <String, dynamic>{};
    if (rawPreferences is Map) {
      for (final entry in rawPreferences.entries) {
        preferences[entry.key.toString()] = entry.value;
      }
    }
    return firstIncompleteOnboardingRoute(
      preferences: preferences,
      source: source,
    );
  }

  static const wishlist = '/wishlist';

  static const blendHub = '/blend';

  static const blendLobby = '/blend/lobby';
  static const blendSwipe = '/blend/swipe';
  static const blendResults = '/blend/results';
  static const blendChat = '/blend/chat';
  static const blendDashboard = '/blend/dashboard';
  static const blendWishlist = '/blend/wishlist';
  static const blendMoodboard = '/blend/moodboard';

  static const verifyEmail = '/verify-email';
  static const notifications = '/notifications';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const allCreators = '/all-creators';

  // Wardrobe / Style
  static const wardrobe = '/wardrobe';
  static const outfitBuilder = '/outfit-builder';
  static const persona = '/persona';
  static const aiStylist = '/ai-stylist';
  static const aiStyleDna = '/ai-style-dna';
  static const editClothing = '/wardrobe/edit-clothing';

  static const createBlend = '/create-blend';
  static const addItem = '/add-item';
  static const joinBlend = '/join-blend';
  static const preferredStyles = '/preferred-styles';
  static const discoveryPreferences = '/discovery-preferences';
  static const discover = '/discover';
  static const swipeDiscovery = '/swipe-discovery';
  static const settings = '/settings';
  static const analyticsDashboard = '/analytics-dashboard';
  static const termsOfService = '/terms-of-service';
  static const privacyPolicy = '/privacy-policy';
  static const userProfile = '/user-profile';
  static const friends = '/friends';
}

class ProductDetailsRouteExtra {
  const ProductDetailsRouteExtra({required this.productId});

  final String productId;
}

class EditClothingRouteExtra {
  const EditClothingRouteExtra({required this.wardrobeItem});

  final WardrobeItem wardrobeItem;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

Page<dynamic> _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  SharedAxisTransitionType transitionType = SharedAxisTransitionType.scaled,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: transitionType,
        child: child,
      );
    },
  );
}

Page<dynamic> _buildPageWithFadeTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

GoRouter createRouter({
  required ValueNotifier<bool> authNotifier,
  required ValueNotifier<bool> onboardingCompleteNotifier,
  required ValueNotifier<bool> ageVerifiedNotifier,
  required VoidCallback onToggleTheme,
}) {
  // By default go_router keeps browser pushes out of the address bar, so a
  // route opened with context.push() (e.g. product details from the feed)
  // would leave the URL stuck on the previous page. Opt in so the URL always
  // reflects the top-most route — every pushed route below reads its params
  // from the URI (no `extra` fallback required), making them shareable and
  // reload-safe, and enabling the browser Back button.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: AppRoutes.splash,
    navigatorKey: _rootNavigatorKey,
    refreshListenable: Listenable.merge([
      authNotifier,
      onboardingCompleteNotifier,
      ageVerifiedNotifier,
    ]),
    redirect: (context, state) {
      final isLoggedIn = authNotifier.value;
      final isOnboardingDone = onboardingCompleteNotifier.value;

      // GoRouter's matchedLocation is based on the path portion.
      // However, navigation sometimes includes query params, and we
      // want onboarding to be treated as a path-prefix match (query-agnostic).
      final location = state.matchedLocation;
      debugPrint(

        'ageVerified=${ageVerifiedNotifier.value} onboarding=$isOnboardingDone',
      );

      final isAuthRoute =
          location == AppRoutes.login ||
          location == AppRoutes.signUp ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.splash ||
          location == AppRoutes.welcome ||
          location == AppRoutes.verifyEmail ||
          location == AppRoutes.ageVerification ||
          location == AppRoutes.termsOfService ||
          location == AppRoutes.privacyPolicy;

      final isOnboardingRoute =
          location == AppRoutes.onboarding ||
          location.startsWith(AppRoutes.favoriteCategories) ||
          location.startsWith(AppRoutes.preferredStyles) ||
          location.startsWith(AppRoutes.discoveryPreferences) ||
          location.startsWith(AppRoutes.persona);

      if (!isLoggedIn && !isAuthRoute && !isOnboardingRoute) {
        return AppRoutes.splash;
      }

      if (isLoggedIn &&
          !ageVerifiedNotifier.value &&
          location != AppRoutes.ageVerification &&
          !isAuthRoute) {
        return AppRoutes.ageVerification;
      }

      // A verified user must never be parked on the age gate. This happens on
      // cold start (the notifier starts false until auth sync resolves) and
      // after a previously failed sync corrects itself — without this rule the
      // router has no way back out of /age-verification.
      if (isLoggedIn &&
          ageVerifiedNotifier.value &&
          location == AppRoutes.ageVerification) {
        return isOnboardingDone ? AppRoutes.home : AppRoutes.onboarding;
      }

      // If logged in but onboarding not complete, force onboarding flow
      // (unless already on an onboarding route).
      if (isLoggedIn &&
          !isOnboardingDone &&
          !isOnboardingRoute &&
          !isAuthRoute) {
        return AppRoutes.onboarding;
      }

      // If onboarding is already complete but we're still sitting on an
      // onboarding step (e.g. a returning user resumed mid-wizard), leave it.
      if (isLoggedIn && isOnboardingDone && isOnboardingRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.ageVerification,
        builder: (context, state) => const AgeVerificationScreen(),
      ),
      GoRoute(path: AppRoutes.root, redirect: (_, _) => AppRoutes.splash),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return GlassAppShell(
            currentLocation: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.trends,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, TrendsScreen()),
          ),
          GoRoute(
            path: AppRoutes.wishlist,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, WishlistScreen()),
          ),
          GoRoute(
            path: AppRoutes.inspo,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, InspoScreen()),
          ),
          GoRoute(
            path: AppRoutes.wardrobe,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, ClosetScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiStylist,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, const AiStylistScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiStyleDna,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, const AiStyleDnaScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, ProfileScreen()),
          ),
          GoRoute(
            path: AppRoutes.blendHub,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, BlendHubScreen()),
          ),
          GoRoute(
            path: AppRoutes.discover,
            pageBuilder: (context, state) =>
                _buildPageWithFadeTransition(context, state, DiscoverScreen()),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.categories,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, CategoriesScreen()),
      ),

      GoRoute(
        path: AppRoutes.productDetails,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final details = extra is ProductDetailsRouteExtra ? extra : null;

          if (details == null) {
            final productId = state.uri.queryParameters['productId'];
            if (productId != null && productId.isNotEmpty) {
              return _buildPageWithTransition(
                context,
                state,
                ProductDetailsScreen(productId: productId),
              );
            }
            return _buildPageWithTransition(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }

          return _buildPageWithTransition(
            context,
            state,
            ProductDetailsScreen(productId: details.productId),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.allCreators,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, AllCreatorsScreen()),
      ),

      GoRoute(
        path: AppRoutes.search,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final initialQuery = state.uri.queryParameters['q'];
          final initialCategory = state.uri.queryParameters['category'];
          final initialSubcategory = state.uri.queryParameters['subcategory'];
          final initialSort = state.uri.queryParameters['sort'];
          final initialMinPrice = state.uri.queryParameters['min_price'];
          final initialMaxPrice = state.uri.queryParameters['max_price'];
          return _buildPageWithTransition(
            context,
            state,
            SearchScreen(
              initialQuery: initialQuery,
              initialCategory: initialCategory,
              initialSubcategory: initialSubcategory,
              initialSort: initialSort,
              initialMinPrice: initialMinPrice,
              initialMaxPrice: initialMaxPrice,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          LoginScreen(),
          transitionType: SharedAxisTransitionType.horizontal,
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          SignUpScreen(),
          transitionType: SharedAxisTransitionType.horizontal,
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          ForgotPasswordScreen(),
          transitionType: SharedAxisTransitionType.horizontal,
        ),
      ),
      GoRoute(
        path: AppRoutes.favoriteBrands,
        redirect: (_, _) => AppRoutes.favoriteCategories,
      ),
      GoRoute(
        path: AppRoutes.favoriteCategories,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          FavoriteCategoriesScreen(),
          transitionType: SharedAxisTransitionType.horizontal,
        ),
      ),
      GoRoute(
        path: AppRoutes.favoriteColors,
        redirect: (_, _) => AppRoutes.discoveryPreferences,
      ),
      GoRoute(
        path: AppRoutes.preferredBudget,
        redirect: (_, _) => AppRoutes.discoveryPreferences,
      ),
      GoRoute(
        path: AppRoutes.shoppingPriorities,
        redirect: (_, _) => AppRoutes.discoveryPreferences,
      ),
      GoRoute(
        path: AppRoutes.discoveryPreferences,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          DiscoveryPreferencesScreen(),
          transitionType: SharedAxisTransitionType.horizontal,
        ),
      ),
      GoRoute(
        path: AppRoutes.discoverPreferences,
        redirect: (_, _) => AppRoutes.favoriteCategories,
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, VerifyEmailScreen()),
      ),

      GoRoute(
        path: AppRoutes.blendLobby,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            BlendLobbyScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendSwipe,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            BlendSwipeScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendResults,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            BlendResultsScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/chat/direct',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          DirectChatScreen(
            friendFirebaseUid: state.uri.queryParameters['uid'] ?? '',
            friendName: state.uri.queryParameters['name'] ?? 'Friend',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.blendChat,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return _buildPageWithTransition(context, state, BlendChatScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.blendDashboard,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            BlendDashboardScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendWishlist,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            SharedWishlistScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.blendMoodboard,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          return _buildPageWithTransition(
            context,
            state,
            MoodboardScreen(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.outfitBuilder,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, OutfitBuilderScreen()),
      ),
      GoRoute(
        path: AppRoutes.persona,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, PersonaScreen()),
      ),

      GoRoute(
        path: AppRoutes.decision,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final decisionExtra = extra is decision_flow.DecisionRouteExtra
              ? extra
              : null;

          if (decisionExtra == null) {
            return _buildPageWithTransition(
              context,
              state,
              const _MissingRouteExtraWidget(),
            );
          }

          return _buildPageWithTransition(
            context,
            state,
            DecisionScreen(
              query: decisionExtra.query,
              selectedOptions: decisionExtra.selectedOptions
                  .map((o) => o.product)
                  .toList(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, NotificationsScreen()),
      ),
      GoRoute(
        path: AppRoutes.cart,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => AppRoutes.wishlist,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, CartScreen()),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => AppRoutes.wishlist,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const CheckoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.addItem,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const AddItemScreen()),
      ),
      GoRoute(
        path: AppRoutes.editClothing,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra as EditClothingRouteExtra;
          return _buildPageWithTransition(
            context,
            state,
            EditClothingScreen(item: extra.wardrobeItem),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.joinBlend,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, JoinBlendScreen()),
      ),
      GoRoute(
        path: AppRoutes.preferredStyles,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, PreferredStylesScreen()),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          UserProfileScreen(uid: state.uri.queryParameters['uid']),
        ),
      ),
      GoRoute(
        path: AppRoutes.swipeDiscovery,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, SwipeDiscoveryScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.analyticsDashboard,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          AnalyticsDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, TermsOfServiceScreen()),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppRoutes.createBlend,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, CreateBlendScreen()),
      ),
      GoRoute(
        path: AppRoutes.account,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildPageWithTransition(
          context,
          state,
          AccountScreen(onToggleTheme: onToggleTheme),
        ),
      ),
      GoRoute(
        path: AppRoutes.friends,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildPageWithTransition(context, state, const FriendsScreen()),
      ),
    ],
    errorBuilder: (context, state) {
      final c = context.trenzyColors;
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_off_rounded, size: 64, color: c.mutedFg),
                const SizedBox(height: 16),
                DisplayText(
                  'Page Not Found',
                  fontSize: 22,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist or has been moved.',
                  style: GlassTypography.body(color: c.mutedFg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Back to Home',
                  onTap: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MissingRouteExtraWidget extends StatelessWidget {
  const _MissingRouteExtraWidget();

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GlassBackButton(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 56, color: c.mutedFg),
              const SizedBox(height: 16),
              DisplayText(
                'Item Not Available',
                fontSize: 20,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load the requested item details.',
                style: GlassTypography.body(color: c.mutedFg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GlowButton(
                label: 'Go Back',
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}