import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/providers/products_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/services/api_service.dart';
import 'package:trenzy/providers/search_providers.dart';
import 'package:trenzy/analytics/events.dart';
import 'package:trenzy/widgets/section_states.dart';

// ── Recent search persistence ──────────────────────────────────────────────
const _kMaxRecentSearches = 10;

class _RecentSearchesNotifier extends StateNotifier<List<String>> {
  _RecentSearchesNotifier() : super([]);

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [q, ...state.where((s) => s != q)].take(_kMaxRecentSearches).toList();
  }

  void remove(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clear() {
    state = [];
  }
}

final recentSearchesProvider =
    StateNotifierProvider<_RecentSearchesNotifier, List<String>>(
  (_) => _RecentSearchesNotifier(),
);

// ── Trending searches (static for now, can be wired to API later) ──────────
const _kTrendingSearches = [
  'Oversized blazer',
  'Minimal sneakers',
  'Streetwear hoodie',
  'Linen trousers',
  'Gold jewelry',
  'Leather bag',
  'Y2K aesthetic',
  'Quiet luxury',
];

// ── Main screen ────────────────────────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialSubcategory,
    this.initialSort,
    this.initialMinPrice,
    this.initialMaxPrice,
  });
  final String? initialQuery;
  final String? initialCategory;
  final String? initialSubcategory;
  final String? initialSort;
  final String? initialMinPrice;
  final String? initialMaxPrice;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _hasSubmitted = false;
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _query = widget.initialQuery!;
      _hasSubmitted = true;
    }
    if (widget.initialCategory != null) {
      _controller.text = widget.initialSubcategory != null 
          ? '${widget.initialCategory!} > ${widget.initialSubcategory!}' 
          : widget.initialCategory!;
      _query = widget.initialCategory!;
      _hasSubmitted = true;
    }
    // Store initial filters for search results
    _initialFilters = {
      'category': widget.initialCategory,
      'subcategory': widget.initialSubcategory,
      'sort': widget.initialSort,
      'min_price': widget.initialMinPrice,
      'max_price': widget.initialMaxPrice,
    };
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    final text = _controller.text;
    if (text.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _debouncedQuery = text);
        }
      });
    } else {
      setState(() => _debouncedQuery = '');
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory ||
        widget.initialSubcategory != oldWidget.initialSubcategory ||
        widget.initialQuery != oldWidget.initialQuery) {
      if (widget.initialCategory != null) {
        _controller.text = widget.initialSubcategory != null
            ? '${widget.initialCategory!} > ${widget.initialSubcategory!}'
            : widget.initialCategory!;
        _query = widget.initialCategory!;
        _hasSubmitted = true;
      } else if (widget.initialQuery != null) {
        _controller.text = widget.initialQuery!;
        _query = widget.initialQuery!;
        _hasSubmitted = true;
      }
      _initialFilters = {
        'category': widget.initialCategory,
        'subcategory': widget.initialSubcategory,
        'sort': widget.initialSort,
        'min_price': widget.initialMinPrice,
        'max_price': widget.initialMaxPrice,
      };
    }
  }
  
  Map<String, String?> _initialFilters = {};

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _submitSearch(String query) {
    final sanitized = query.trim();
    if (sanitized.isEmpty) return;
    setState(() {
      _query = sanitized;
      _hasSubmitted = true;
    });
    ref.read(recentSearchesProvider.notifier).add(sanitized);
    trackSearch(ref, sanitized);
    _focusNode.unfocus();
  }

  void _selectRecent(String query) {
    _controller.text = query;
    _submitSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final recentSearches = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassBackButton(
                    onTap: () {
                      if (_hasSubmitted) {
                        setState(() {
                          _hasSubmitted = false;
                          _query = '';
                          _controller.clear();
                        });
                      } else {
                        context.pop();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GlassSearchBar(
                      controller: _controller,
                      hintText: 'Search brands, styles, creators...',
                      onTap: () => setState(() => _hasSubmitted = false),
                      trailing: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  color: context.trenzyColors.mutedFg, size: 18),
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _query = '';
                                  _hasSubmitted = false;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: () => _submitSearch(_controller.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.trenzyColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.search_rounded,
                          color: context.trenzyColors.primaryFg, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search suggestions ───────────────────────────────────────
            if (!_hasSubmitted && _debouncedQuery.length >= 2)
              _SuggestionsOverlay(
                query: _debouncedQuery,
                onSelect: (suggestion) {
                  _controller.text = suggestion;
                  _submitSearch(suggestion);
                },
              ),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: _hasSubmitted
                  ? _SearchResults(query: _query, initialFilters: _initialFilters)
                  : _BrowseView(
                      recentSearches: recentSearches,
                      onRecentTap: _selectRecent,
                      onRecentRemove: (q) =>
                          ref.read(recentSearchesProvider.notifier).remove(q),
                      onClearRecent: () =>
                          ref.read(recentSearchesProvider.notifier).clear(),
                      onTrendingTap: _selectRecent,
                      onCategoryTap: (category) {
                        _controller.text = category;
                        _submitSearch(category);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions overlay (shown while typing) ───────────────────────────────
class _SuggestionsOverlay extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onSelect;
  const _SuggestionsOverlay({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider(query));
    return suggestionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 32,
          child: Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: context.trenzyColors.crimson),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Suggestions are unavailable right now',
                style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg),
              ),
            ),
          ],
        ),
      ),
      data: (suggestions) {
        if (suggestions.isEmpty) return SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: context.trenzyColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return InkWell(
                onTap: () => onSelect(suggestion),
                borderRadius: index == 0
                    ? BorderRadius.vertical(top: Radius.circular(12))
                    : index == suggestions.length - 1
                        ? BorderRadius.vertical(bottom: Radius.circular(12))
                        : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 18, color: context.trenzyColors.mutedFg),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 14,
                            color: context.trenzyColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Browse view (shown before search) ──────────────────────────────────────
class _BrowseView extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTrendingTap;
  final ValueChanged<String> onCategoryTap;

  const _BrowseView({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onClearRecent,
    required this.onTrendingTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // ── Recent searches ─────────────────────────────────────────────
        if (recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.trenzyColors.foreground,
                  ),
                ),
                GestureDetector(
                  onTap: onClearRecent,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.trenzyColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          ...recentSearches.map(
            (query) => ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading:
                  Icon(Icons.history, color: context.trenzyColors.mutedFg, size: 20),
              title: Text(
                query,
                style: TextStyle(color: context.trenzyColors.foreground, fontSize: 14),
              ),
              trailing: GestureDetector(
                onTap: () => onRecentRemove(query),
                child: Icon(Icons.close,
                    color: context.trenzyColors.mutedFg, size: 16),
              ),
              onTap: () => onRecentTap(query),
            ),
          ),
          SizedBox(height: 8),
        ],

        // ── Trending searches ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: context.trenzyColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Trending Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.trenzyColors.foreground,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kTrendingSearches.map((term) {
              return GestureDetector(
                onTap: () => onTrendingTap(term),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.graphite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.trenzyColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded,
                          color: context.trenzyColors.primary, size: 14),
                      SizedBox(width: 6),
                      Text(
                        term,
                        style: TextStyle(
                          color: context.trenzyColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        SizedBox(height: 24),

        // ── Browse categories ──────────────────────────────────────────
        _CategoryChips(onCategoryTap: onCategoryTap),

        SizedBox(height: 16),

        // ── Swipe discovery ────────────────────────────────────────────
        _SwipeDiscoveryCard(),

        SizedBox(height: 32),
      ],
    );
  }
}

// ── Category chips ─────────────────────────────────────────────────────────
class _CategoryChips extends ConsumerWidget {
  final ValueChanged<String> onCategoryTap;
  const _CategoryChips({required this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Browse Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.trenzyColors.foreground,
            ),
          ),
        ),
        SizedBox(height: 12),
        categoriesAsync.when(
          loading: () => SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.trenzyColors.primary,
                ),
              ),
            ),
          ),
          error: (_, _) => ErrorSection(
            title: 'Categories unavailable',
            message: 'Couldn\u2019t load the category list.',
            compact: true,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (categories) {
            if (categories.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return GlassTag(
                    text: cat,
                    onTap: () => onCategoryTap(cat),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Search results ─────────────────────────────────────────────────────────
class _SearchResults extends ConsumerWidget {
  final String query;
  final Map<String, String?> initialFilters;
  const _SearchResults({required this.query, required this.initialFilters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minPriceStr = initialFilters['min_price'];
    final maxPriceStr = initialFilters['max_price'];
    final double? minPrice =
        (minPriceStr == null || minPriceStr.isEmpty) ? null : double.tryParse(minPriceStr);
    final double? maxPrice =
        (maxPriceStr == null || maxPriceStr.isEmpty) ? null : double.tryParse(maxPriceStr);
    final params = ProductSearchParams(
      query: query,
      category: initialFilters['category'],
      subcategory: initialFilters['subcategory'],
      sort: initialFilters['sort'] ?? 'relevance',
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    final productsAsync = ref.watch(productSearchProvider(params));

    return productsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 24,
              child: LoadingSkeletonShimmer(height: 20, radius: 6),
            ),
            SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: 6,
                itemBuilder: (_, _) => ProductCardSkeleton(),
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _SearchErrorView(
        query: query,
        error: error,
        onRetry: () => ref.invalidate(productSearchProvider(params)),
      ),
      data: (products) {
        if (products.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${products.length} product${products.length == 1 ? '' : 's'} found',
              style: TextStyle(
                color: context.trenzyColors.mutedFg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return GlassContainer(
                  color: context.trenzyColors.graphite,
                  radius: 16,
                  onTap: () {
                    context.push(
                      AppRoutes.productDetailsFor(product.id),
                      extra: ProductDetailsRouteExtra(productId: product.id),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: ApiService.resolveImageUrl(product.imageUrl) ?? product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, _) => Container(color: Colors.grey[900]),
                                    errorWidget: (_, _, _) =>
                                        Icon(Icons.image_outlined,
                                            color: context.trenzyColors.mutedFg),
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.brand.toUpperCase(),
                              style: TextStyle(
                                color: context.trenzyColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              product.name,
                              style: TextStyle(
                                color: context.trenzyColors.foreground,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ...[
                            SizedBox(height: 4),
                            Text(
                              '\u20B9${product.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: context.trenzyColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ── No results view ────────────────────────────────────────────────────────
class _NoResultsView extends StatelessWidget {
  final String query;
  const _NoResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: context.trenzyColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.trenzyColors.foreground,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We couldn\'t find anything for "$query".\nTry different keywords or browse categories.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            GlowButton(
              label: 'Browse Categories',
              width: 200,
              onTap: () {
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search error view (distinct from empty results) ────────────────────────
class _SearchErrorView extends StatelessWidget {
  final String query;
  final Object error;
  final VoidCallback onRetry;
  const _SearchErrorView({
    required this.query,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.trenzyColors.crimson.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: context.trenzyColors.crimson,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Couldn\'t load results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.trenzyColors.foreground,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We hit a problem searching for "$query".\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            GlowButton(
              label: 'Try Again',
              width: 200,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Swipe discovery card ───────────────────────────────────────────────────
class _SwipeDiscoveryCard extends StatelessWidget {
  const _SwipeDiscoveryCard();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      color: context.trenzyColors.graphite,
      radius: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => context.push(AppRoutes.swipeDiscovery),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.trenzyColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.swipe_rounded,
                  size: 28, color: context.trenzyColors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Swipe Discovery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.trenzyColors.foreground,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Let our AI learn your style, one swipe at a time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.trenzyColors.mutedFg,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: context.trenzyColors.mutedFg),
          ],
        ),
      ),
    );
  }
}