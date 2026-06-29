import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trend_model.dart';
import '../models/user_model.dart';
import '../providers/api_service_provider.dart';
import '../providers/trends_provider.dart';
import '../providers/auth_provider.dart' as auth_p;

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeframe = 'daily';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(auth_p.authProvider);
    final trendingParams = TrendingParams(
      timeframe: _selectedTimeframe,
      limit: 20,
    );
    final predictionsParams = const PredictionParams(limit: 10);

    final trendingAsync = ref.watch(trendingProductsProvider(trendingParams));
    final predictionsAsync = ref.watch(
      trendPredictionsProvider(predictionsParams),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('🔥 Trending Now'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live Trends'),
            Tab(text: 'Trending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrendsList(trendingAsync, auth),
          _buildPredictionsList(predictionsAsync, auth),
        ],
      ),
    );
  }

  Widget _buildTrendsList(
    AsyncValue<List<TrendModel>> asyncData,
    AsyncValue<UserModel?> auth,
  ) {
    if (auth.isLoading || auth.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TimeframeChip(
                label: 'Hourly',
                selected: _selectedTimeframe == 'hourly',
                onTap: () => setState(() => _selectedTimeframe = 'hourly'),
              ),
              const SizedBox(width: 8),
              _TimeframeChip(
                label: 'Daily',
                selected: _selectedTimeframe == 'daily',
                onTap: () => setState(() => _selectedTimeframe = 'daily'),
              ),
              const SizedBox(width: 8),
              _TimeframeChip(
                label: 'Weekly',
                selected: _selectedTimeframe == 'weekly',
                onTap: () => setState(() => _selectedTimeframe = 'weekly'),
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncData.when(
            data: (trends) {
              if (trends.isEmpty) {
                return const Center(
                  child: Text(
                    'Building trending list...\nBrowse products to see popular items',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trends.length,
                itemBuilder: (context, index) {
                  final trend = trends[index];
                  return _TrendCardItem(
                    trend: trend,
                    rank: index + 1,
                    onTap: () => _onProductTap(trend.productId),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $error'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(trendingProductsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsList(
    AsyncValue<List<PredictionModel>> asyncData,
    AsyncValue<UserModel?> auth,
  ) {
    if (auth.isLoading || auth.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return asyncData.when(
      data: (predictions) {
        if (predictions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Building your trends...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse products to see trending items here',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: predictions.length,
          itemBuilder: (context, index) {
            final prediction = predictions[index];
            return _PredictionCardItem(
              prediction: prediction,
              rank: index + 1,
              onTap: () => _onProductTap(prediction.productId),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $error'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(trendPredictionsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _onProductTap(String productId) async {
    final api = ref.read(apiServiceProvider);
    await api.trackProductView(productId);
  }
}

class _TimeframeChip extends StatelessWidget {
  const _TimeframeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TrendCardItem extends StatelessWidget {
  const _TrendCardItem({
    required this.trend,
    required this.rank,
    required this.onTap,
  });

  final TrendModel trend;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTopThree = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTopThree
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isTopThree ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${trend.viewCount} views',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (trend.momentum > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${(trend.momentum * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trend.trendingScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Text('score', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PredictionCardItem extends StatelessWidget {
  const _PredictionCardItem({
    required this.prediction,
    required this.rank,
    required this.onTap,
  });

  final PredictionModel prediction;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prediction.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prediction.reasoning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Confidence:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: prediction.confidence / 100,
                        minHeight: 8,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${prediction.confidence.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
