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
import 'package:trenzy/widgets/product_card.dart';
import 'package:trenzy/analytics/events.dart';
import 'package:trenzy/widgets/section_states.dart';

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
    final text = _controller.text.trim();
    if (text.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted || _controller.text.trim() != text) return;
        setState(() {
          _debouncedQuery = text;
          _query = text;
          // Show matching results automatically while the user types.
          // The explicit search button remains available for immediate submit.
          _hasSubmitted = true;
        });
      });
    } else {
      setState(() {
        _debouncedQuery = '';
        _query = '';
        _hasSubmitted = false;
      });
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
    _debounceTimer?.cancel();
    setState(() {
      _query = sanitized;
      _debouncedQuery = sanitized;
      _hasSubmitted = true;
    });
    trackSearch(ref, sanitized);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
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
                          _debouncedQuery = '';
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
                              icon: Icon(
                                Icons.close,
                                color: context.trenzyColors.mutedFg,
                                size: 18,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _query = '';
                                  _debouncedQuery = '';
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
                      child: Icon(
                        Icons.search_rounded,
                        color: context.trenzyColors.primaryFg,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: _hasSubmitted
                  ? _SearchResults(
                      query: _query,
                      initialFilters: _initialFilters,
                    )
                  : _BrowseView(
                      onCategoryTap: (category) {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _initialFilters = {
                            ..._initialFilters,
                            'category': category,
                            'subcategory': null,
                          };
                          _hasSubmitted = true;
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              leading: Icon(
                Icons.history,
                color: context.trenzyColors.mutedFg,
                size: 20,
              ),
              title: Text(
                query,
                style: TextStyle(
                  color: context.trenzyColors.foreground,
                  fontSize: 14,
                ),
              ),
              trailing: GestureDetector(
                onTap: () => onRecentRemove(query),
                child: Icon(
                  Icons.close,
                  color: context.trenzyColors.mutedFg,
                  size: 16,
                ),
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
              Icon(
                Icons.trending_up_rounded,
                color: context.trenzyColors.primary,
                size: 18,
              ),
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
       // ── Browse view: categories only; no suggested/recent/trending queries ──
class _BrowseView extends StatelessWidget {
  final ValueChanged<String> onCategoryTap;

  const _BrowseView({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _CategoryChips(onCategoryTap: onCategoryTap),
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
                  return GlassTag(text: cat, onTap: () => onCategoryTap(cat));
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
    final category = initialFilters['category']?.trim();
    final minPrice = double.tryParse(initialFilters['min_price'] ?? '');
    final maxPrice = double.tryParse(initialFilters['max_price'] ?? '');
    final sort = initialFilters['sort'] == 'rating'
        ? 'rating_desc'
        : initialFilters['sort'];
    final hasProductFilters = (category != null && category.isNotEmpty) ||
        minPrice != null || maxPrice != null || sort != null;

    if (hasProductFilters) {
      final params = ProductSearchParams(
        query: query,
        category: category?.isEmpty == true ? null : category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sort: sort,
      );
      final productsAsync = ref.watch(productSearchProvider(params));
      return productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorSection(
          title: 'Could not load filtered products',
          message: 'Please try again in a moment.',
          onRetry: () => ref.invalidate(productSearchProvider(params)),
        ),
        data: (products) {
          if (products.isEmpty) {
            return _NoResultsView(query: category?.isNotEmpty == true ? category! : query);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return ProductCard(
                product: product,
                variant: ProductCardVariant.standard,
                heroTagSuffix: '_filtered_${product.id}_$index',
                onTap: () => context.push(AppRoutes.productDetailsFor(product.id)),
              );
            },
          );
        },
      );
    }
    final unifiedSearchAsync = ref.watch(unifiedSearchProvider(query));

    return unifiedSearchAsync.when(
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
        onRetry: () => ref.invalidate(unifiedSearchProvider(query)),
      ),
      data: (searchResults) {
        final products = searchResults['products'] ?? [];
        final users = searchResults['users'] ?? [];
        final blends = searchResults['blends'] ?? [];

        if (products.isEmpty && users.isEmpty && blends.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Users section
            if (users.isNotEmpty) ...[
              Text(
                '${users.length} user${users.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: context.trenzyColors.mutedFg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return GlassContainer(
                    color: context.trenzyColors.graphite,
                    radius: 12,
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () {
                      // Navigate to user profile
                      context.push(
                        AppRoutes.userProfileFor(user['id'].toString()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                user['avatarUrl'] != null &&
                                    user['avatarUrl'].isNotEmpty
                                ? CachedNetworkImageProvider(
                                    ApiService.resolveImageUrl(
                                          user['avatarUrl'],
                                        ) ??
                                        user['avatarUrl'],
                                  )
                                : null,
                            child:
                                user['avatarUrl'] == null ||
                                    user['avatarUrl'].isEmpty
                                ? Icon(
                                    Icons.person,
                                    color: context.trenzyColors.mutedFg,
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'],
                                  style: TextStyle(
                                    color: context.trenzyColors.foreground,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (user['username'] != null &&
                                    user['username'].isNotEmpty)
                                  Text(
                                    '@${user['username']}',
                                    style: TextStyle(
                                      color: context.trenzyColors.mutedFg,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
            ],

            // Products section
            if (products.isNotEmpty) ...[
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
                                imageUrl:
                                    ApiService.resolveImageUrl(
                                      product.imageUrl,
                                    ) ??
                                    product.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, _) =>
                                    Container(color: Colors.grey[900]),
                                errorWidget: (_, _, _) => Icon(
                                  Icons.image_outlined,
                                  color: context.trenzyColors.mutedFg,
                                ),
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
                              SizedBox(height: 4),
                              Text(
                                product.hasPrice ? '\u20B9${product.displayPrice.toStringAsFixed(0)}' : 'Price unavailable',
                                style: TextStyle(
                                  color: context.trenzyColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
            GlowButton(label: 'Try Again', width: 200, onTap: onRetry),
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
              child: Icon(
                Icons.swipe_rounded,
                size: 28,
                color: context.trenzyColors.primary,
              ),
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
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.trenzyColors.mutedFg,
            ),
          ],
        ),
      ),
    );
  }
}
