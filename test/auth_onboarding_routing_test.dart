import 'package:flutter_test/flutter_test.dart';
import 'package:trenzy/router/app_router.dart';

void main() {
  group('firstIncompleteOnboardingRoute', () {
    test('resumes the persisted onboarding step', () {
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 0},
        ),
        AppRoutes.onboarding,
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 1},
        ),
        '${AppRoutes.favoriteCategories}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 2},
        ),
        '${AppRoutes.preferredStyles}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 3},
        ),
        '${AppRoutes.discoveryPreferences}?source=onboarding',
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 4},
        ),
        AppRoutes.persona,
      );
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 5},
        ),
        AppRoutes.home,
      );
    });

    test('unknown or missing progress safely starts onboarding', () {
      expect(AppRoutes.firstIncompleteOnboardingRoute(), AppRoutes.onboarding);
      expect(
        AppRoutes.firstIncompleteOnboardingRoute(
          preferences: {'onboarding_step': 'invalid'},
        ),
        AppRoutes.onboarding,
      );
    });
  });
}


  group('guardRedirect authentication', () {
    test('redirects signed-out users away from onboarding deep links', () {
      for (final route in [
        AppRoutes.onboarding,
        AppRoutes.favoriteCategories,
        AppRoutes.preferredStyles,
        AppRoutes.discoveryPreferences,
        AppRoutes.persona,
      ]) {
        expect(
          AppRoutes.guardRedirect(
            isLoggedIn: false,
            isOnboardingDone: false,
            isAgeVerified: false,
            location: route,
          ),
          AppRoutes.splash,
          reason: 'Signed-out access should be blocked for $route',
        );
      }
    });

    test('keeps signed-out users on public authentication routes', () {
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: false,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.login,
        ),
        isNull,
      );
      expect(
        AppRoutes.guardRedirect(
          isLoggedIn: false,
          isOnboardingDone: false,
          isAgeVerified: false,
          location: AppRoutes.signUp,
        ),
        isNull,
      );
    });
  });
