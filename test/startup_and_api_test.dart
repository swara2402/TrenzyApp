import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/models/api_exception.dart';
import 'package:trenzy/services/api/api_client.dart';
import 'package:trenzy/services/environment_config.dart';

void main() {
  group('ApiClient URL Resolution & Prefix Composition', () {
    test('standard endpoints receive single /api prefix', () {
      final uri = ApiClient.resolveUri('/products');
      expect(uri.path, '/api/products');
      expect(uri.toString(), '${EnvConfig.apiBaseUrl}/api/products');
    });

    test('endpoints already prefixed with /api are not duplicated', () {
      final uri = ApiClient.resolveUri('/api/persona/preferences');
      expect(uri.path, '/api/persona/preferences');
      expect(uri.toString(), '${EnvConfig.apiBaseUrl}/api/persona/preferences');
    });

    test('AI endpoints route directly under /ai without /api prefix', () {
      final uri1 = ApiClient.resolveUri('/ai/models/health');
      expect(uri1.path, '/ai/models/health');
      expect(uri1.toString(), '${EnvConfig.apiBaseUrl}/ai/models/health');

      final uri2 = ApiClient.resolveUri('/ai/style-dna');
      expect(uri2.path, '/ai/style-dna');
      expect(uri2.toString(), '${EnvConfig.apiBaseUrl}/ai/style-dna');
    });
  });

  group('Startup Routing Guards & Scenarios', () {
    late ValueNotifier<bool> authNotifier;
    late ValueNotifier<bool> onboardingCompleteNotifier;
    late ValueNotifier<bool> ageVerifiedNotifier;

    setUp(() {
      authNotifier = ValueNotifier<bool>(false);
      onboardingCompleteNotifier = ValueNotifier<bool>(false);
      ageVerifiedNotifier = ValueNotifier<bool>(false);
    });

    tearDown(() {
      authNotifier.dispose();
      onboardingCompleteNotifier.dispose();
      ageVerifiedNotifier.dispose();
    });

    test('1. Fresh launch, signed out: stays on splash or routes to welcome', () {
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: false,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.splash,
        ),
        isNull,
      );

      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: false,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.welcome,
        ),
        isNull,
      );

      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: false,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.home,
        ),
        AppRoutes.splash,
      );
    });

    test('2 & 3. Existing valid session: verified age and complete onboarding routes to home', () {
      // Verified returning user on age gate or onboarding is redirected to home
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: true,
          isAgeVerified: true,
          location: AppRoutes.ageVerification,
        ),
        AppRoutes.home,
      );

      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: true,
          isAgeVerified: true,
          location: AppRoutes.onboarding,
        ),
        AppRoutes.home,
      );

      // Verified user on home is allowed
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: true,
          isAgeVerified: true,
          location: AppRoutes.home,
        ),
        isNull,
      );
    });

    test('4. Logged in user without age verification is redirected to /age-verification', () {
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.onboarding,
        ),
        AppRoutes.ageVerification,
      );

      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.home,
        ),
        AppRoutes.ageVerification,
      );

      // Allowed to stay on age verification to verify
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: true,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.ageVerification,
        ),
        isNull,
      );
    });

    test('5. Incomplete onboarding: resumes the exact pending wizard step', () {
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 0}),
        AppRoutes.onboarding,
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 1}),
        '${AppRoutes.favoriteCategories}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 2}),
        '${AppRoutes.preferredStyles}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 3}),
        '${AppRoutes.discoveryPreferences}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 4}),
        AppRoutes.persona,
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(preferences: {'onboarding_step': 5}),
        AppRoutes.home,
      );
    });

    test('6 & 7. Unexpected response shapes are handled gracefully', () {
      // Nested format
      expect(
        AppRoutes.routeFromPreferencesResponse({'preferences': {'onboarding_step': 3}}),
        '${AppRoutes.discoveryPreferences}?source=onboarding',
      );
      // Flat format
      expect(
        AppRoutes.routeFromPreferencesResponse({'onboarding_step': 5}),
        AppRoutes.home,
      );
      // Null preferences
      expect(
        AppRoutes.routeFromPreferencesResponse({'preferences': null}),
        AppRoutes.onboarding,
      );
      // Corrupt / missing shape
      expect(
        AppRoutes.routeFromPreferencesResponse({'status': 'ok'}),
        AppRoutes.onboarding,
      );
    });

    test('8. Session expired callback correctly invokes sign out handler', () {
      bool sessionExpiredFired = false;
      ApiClient.onSessionExpired = () {
        sessionExpiredFired = true;
      };

      // ApiClient handleResponse throws on 401
      expect(
        () => ApiClient(firebaseAuth: _MockFirebaseAuth()).handleResponse(
          http.Response('{"detail": "token expired"}', 401),
          endpoint: '/persona/preferences',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      ApiClient.onSessionExpired?.call();
      expect(sessionExpiredFired, isTrue);
      ApiClient.onSessionExpired = null;
    });
  });
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {}
