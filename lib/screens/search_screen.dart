import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../providers/products_provider.dart';
import '../providers/trends_provider.dart';
import '../providers/analytics_service_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/product_card.dart';
import '../theme/app_spacing.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    required this.onToggleTheme,
    this.initialQuery,
    this.initialCategory,
  });

  final VoidCallback onToggleTheme;
  final String? initialQuery;
  final String? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  String _sort = 'relevance';
  double? _minPrice;
  double? _maxPrice;
  String? _category;
  ProductSearchParams? _activeParams;

  // Debounce timer for auto-search on typing
  Timer? _debounceTimer;

  // Recent searches (session-only for MVP)
  static final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _category = widget.initialCategory;
    if ((widget.initialQuery?.trim().isNotEmpty ?? false) ||
        widget.initialCategory != null) {
      _runSearch();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _runSearch() {
    final query = _controller.text.trim();

    setState(() {
      _activeParams = ProductSearchParams(
        query: query,
        category: _category,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sort: _sort,
      );
    });

    // Add to recent searches
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }

    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: 'search',
          parameters: {
            'query': query,
            if (_category != null) 'category': _category,
            'sort': _sort,
          },
        );
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {}); // update clear button visibility
    if (value.trim().isEmpty) return;
    _debounceTimer = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final resultsAsync = _activeParams == null
        ? const AsyncValue<List<ProductModel>>.data([])
        : ref.watch(productSearchProvider(_activeParams!));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Search Products'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search outfits, shoes, accessories...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            _debounceTimer?.cancel();
                            setState(() => _activeParams = null);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                ),
                onSubmitted: (_) {
                  _debounceTimer?.cancel();
                  _runSearch();
                },
                onChanged: _onSearchChanged,
              ),
            ),
            // Filter chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterChip(
                    label: Text(_category ?? 'Category'),
                    selected: _category != null,
                    onSelected: (_) async {
                      final categories = categoriesAsync.maybeWhen(
                        data: (value) => value,
                        orElse: () => const <String>[],
                      );
                      if (categories.isEmpty) return;

                      final picked = await showModalBottomSheet<String>(
                        context: context,
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.clear_rounded),
                                  title: const Text('All categories'),
                                  onTap: () => Navigator.pop(context),
                                ),
                                for (final category in categories)
                                  ListTile(
                                    title: Text(category),
                                    onTap: () =>
                                        Navigator.pop(context, category),
                                  ),
                              ],
                            ),
                          );
                        },
                      );

                      if (!mounted) return;
                      setState(() => _category = picked);
                      _runSearch();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Under ₹500'),
                    selected: _maxPrice == 500,
                    onSelected: (selected) {
                      setState(() {
                        _maxPrice = selected ? 500 : null;
                        _minPrice = null;
                      });
                      _runSearch();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('₹500+'),
                    selected: _minPrice == 500,
                    onSelected: (selected) {
                      setState(() {
                        _minPrice = selected ? 500 : null;
                        _maxPrice = null;
                      });
                      _runSearch();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('₹1000+'),
                    selected: _minPrice == 1000,
                    onSelected: (selected) {
                      setState(() {
                        _minPrice = selected ? 1000 : null;
                        _maxPrice = null;
                      });
                      _runSearch();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Best match'),
                    selected: _sort == 'match_desc',
                    onSelected: (selected) {
                      setState(
                        () => _sort = selected ? 'match_desc' : 'relevance',
                      );
                      _runSearch();
                    },
                  ),
                ],
              ),
            ),
            // Results area
            Expanded(
              child: resultsAsync.when(
                loading: () => _SearchSkeleton(),
                error: (e, _) {
                  final params = _activeParams;
                  if (params == null) {
                    return _SearchIdleState(
                      recentSearches: _recentSearches,
                      onRecentTap: (q) {
                        _controller.text = q;
                        _runSearch();
                      },
                    );
                  }
                  return AsyncRetryErrorState(
                    title: 'Search failed',
                    message: 'Could not fetch results. Please try again.',
                    onRetry: () =>
                        ref.invalidate(productSearchProvider(params)),
                  );
                },
                data: (products) {
                  if (_activeParams == null) {
                    return _SearchIdleState(
                      recentSearches: _recentSearches,
                      onRecentTap: (q) {
                        _controller.text = q;
                        _runSearch();
                      },
                    );
                  }

                  if (products.isEmpty) {
                    return _SearchNoResults(
                      query: _activeParams!.query,
                      onClear: () {
                        _controller.clear();
                        setState(() => _activeParams = null);
                      },
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: products[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchIdleState extends ConsumerWidget {
  const _SearchIdleState({
    required this.recentSearches,
    required this.onRecentTap,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trendingAsync = ref.watch(
      trendingProductsProvider(
        const TrendingParams(timeframe: 'daily', limit: 6),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Text(
              'Recent Searches',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches
                  .map(
                    (q) => ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(q),
                      onPressed: () => onRecentTap(q),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Trending Now',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          trendingAsync.when(
            loading: () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                3,
                (_) => const LoadingSkeletonShimmer(
                  height: 36,
                  width: 100,
                  radius: 18,
                ),
              ),
            ),
            error: (e, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const ['Dresses', 'Sneakers', 'Summer tops']
                  .map(
                    (q) => ActionChip(
                      avatar: Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(q),
                      onPressed: null,
                    ),
                  )
                  .toList(),
            ),
            data: (trends) {
              final categories = trends
                  .map((t) => t.category)
                  .whereType<String>()
                  .toSet()
                  .toList();
              final displayCategories = categories.take(6).toList();
              if (displayCategories.isEmpty) {
                return Text(
                  'No trending categories yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayCategories
                    .map(
                      (q) => ActionChip(
                        avatar: Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(q),
                        onPressed: () => onRecentTap(q),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 56,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Search the catalog',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Type to find outfits, shoes, or accessories.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'Nothing matched "$query". Try a different search or adjust filters.'
                  : 'No products match the selected filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ProductGridSkeleton(itemCount: 6);
  }
}
