import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service_provider.dart';
import 'auth_provider.dart' as auth_p;

class UserPreferences {
  final List<String> preferredStyles;
  final List<String> preferredBrands;
  final List<String> preferredCategories;
  final List<String> preferredColors;
  final int? budgetMax;
  final List<String> preferredAesthetics;
  final List<String> preferredSeasons;
  final List<String> preferredOccasions;
  final List<String> discoverPreferences;
  final List<String> productInterests;
  final List<String> shoppingPriorities;

  /// True once the user has finished the onboarding wizard. This is distinct
  /// from having preferences — the wizard must complete fully before the
  /// router stops forcing onboarding.
  final bool onboardingCompleted;

  const UserPreferences({
    this.preferredStyles = const [],
    this.preferredBrands = const [],
    this.preferredCategories = const [],
    this.preferredColors = const [],
    this.budgetMax,
    this.preferredAesthetics = const [],
    this.preferredSeasons = const [],
    this.preferredOccasions = const [],
    this.discoverPreferences = const [],
    this.productInterests = const [],
    this.shoppingPriorities = const [],
    this.onboardingCompleted = false,
  });

  UserPreferences copyWith({
    List<String>? preferredStyles,
    List<String>? preferredBrands,
    List<String>? preferredCategories,
    List<String>? preferredColors,
    int? budgetMax,
    List<String>? preferredAesthetics,
    List<String>? preferredSeasons,
    List<String>? preferredOccasions,
    List<String>? discoverPreferences,
    List<String>? productInterests,
    List<String>? shoppingPriorities,
    bool? onboardingCompleted,
  }) {
    return UserPreferences(
      preferredStyles: preferredStyles ?? this.preferredStyles,
      preferredBrands: preferredBrands ?? this.preferredBrands,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredColors: preferredColors ?? this.preferredColors,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredAesthetics: preferredAesthetics ?? this.preferredAesthetics,
      preferredSeasons: preferredSeasons ?? this.preferredSeasons,
      preferredOccasions: preferredOccasions ?? this.preferredOccasions,
      discoverPreferences: discoverPreferences ?? this.discoverPreferences,
      productInterests: productInterests ?? this.productInterests,
      shoppingPriorities: shoppingPriorities ?? this.shoppingPriorities,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'preferredStyles': preferredStyles,
    'preferredBrands': preferredBrands,
    'preferredCategories': preferredCategories,
    'preferredColors': preferredColors,
    if (budgetMax != null) 'budgetMax': budgetMax,
    'preferredAesthetics': preferredAesthetics,
    'preferredSeasons': preferredSeasons,
    'preferredOccasions': preferredOccasions,
    'discoverPreferences': discoverPreferences,
    'productInterests': productInterests,
    'shoppingPriorities': shoppingPriorities,
  };
}

class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  UserPreferencesNotifier() : super(const UserPreferences());

  void setStyles(List<String> styles) =>
      state = state.copyWith(preferredStyles: styles);
  void setBrands(List<String> brands) =>
      state = state.copyWith(preferredBrands: brands);
  void setCategories(List<String> categories) =>
      state = state.copyWith(preferredCategories: categories);
  void setColors(List<String> colors) =>
      state = state.copyWith(preferredColors: colors);
  void setBudget(int? budget) => state = state.copyWith(budgetMax: budget);
  void setAesthetics(List<String> aesthetics) =>
      state = state.copyWith(preferredAesthetics: aesthetics);
  void setSeasons(List<String> seasons) =>
      state = state.copyWith(preferredSeasons: seasons);
  void setOccasions(List<String> occasions) =>
      state = state.copyWith(preferredOccasions: occasions);
  void setDiscoverPreferences(List<String> preferences) =>
      state = state.copyWith(discoverPreferences: preferences);
  void setProductInterests(List<String> interests) =>
      state = state.copyWith(productInterests: interests);
  void setShoppingPriorities(List<String> priorities) =>
      state = state.copyWith(shoppingPriorities: priorities);
  void reset() => state = const UserPreferences();

  /// Mark the onboarding wizard as finished. The router uses this flag (not
  /// the presence of preferences) to decide when to force the wizard.
  void completeOnboarding() =>
      state = state.copyWith(onboardingCompleted: true);

  void hydrateFromServer(Map<String, dynamic> prefs) {
    state = UserPreferences(
      preferredStyles: _stringList(prefs['preferred_styles']),
      preferredBrands: _stringList(prefs['preferred_brands']),
      preferredCategories: _stringList(prefs['preferred_categories']),
      preferredColors: _stringList(prefs['preferred_colors']),
      budgetMax: prefs['budget_max'] as int?,
      preferredAesthetics: _stringList(prefs['preferred_aesthetics']),
      preferredSeasons: _stringList(prefs['preferred_seasons']),
      preferredOccasions: _stringList(prefs['preferred_occasions']),
      discoverPreferences: _stringList(prefs['discover_preferences']),
      productInterests: _stringList(prefs['product_interests']),
      shoppingPriorities: _stringList(prefs['shopping_priorities']),
      onboardingCompleted: _hasAnySavedPrefs(prefs),
    );
  }

  static bool _hasAnySavedPrefs(Map<String, dynamic> prefs) {
    return _stringList(prefs['preferred_categories']).isNotEmpty ||
        _stringList(prefs['preferred_styles']).isNotEmpty ||
        _stringList(prefs['shopping_priorities']).isNotEmpty ||
        _stringList(prefs['product_interests']).isNotEmpty;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}

/// Server-side preferences shared by every startup reader.
///
/// The splash onboarding check and the hydration listener below need the
/// same `/persona/preferences` response. Reading it through this
/// FutureProvider makes concurrent readers share ONE in-flight request
/// instead of each firing its own HTTP call at startup. Re-fetches
/// automatically when the signed-in account changes.
final serverPreferencesProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final uid = ref.watch(auth_p.authProvider.select((a) => a.valueOrNull?.id));
  if (uid == null || uid.isEmpty) return null;

  final api = ref.read(apiServiceProvider);
  final res = await api.getPreferences();
  final prefs = res['preferences'];
  return prefs is Map<String, dynamic> ? prefs : null;
});

final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
      final notifier = UserPreferencesNotifier();

      // Auto-hydrate from server when auth state changes.
      // Clear the in-memory state immediately when the user signs out so the
      // router doesn't keep driving a stale onboarding completion value.
      ref.listen(auth_p.authProvider, (prev, next) async {
        final uid = next.valueOrNull?.id;
        if (uid == null) {
          notifier.reset();
          return;
        }
        try {
          final prefs = await ref.read(serverPreferencesProvider.future);
          if (prefs != null) {
            notifier.hydrateFromServer(prefs);
          } else {
            notifier.reset();
          }
        } catch (_) {
          // Silently fail — preferences will be empty until next retry
        }
      }, fireImmediately: true);

      return notifier;
    });
