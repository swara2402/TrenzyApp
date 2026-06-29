import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/blend_model.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../router/app_router.dart';
import '../services/blend_socket_service.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';

class BlendSwipeScreen extends ConsumerStatefulWidget {
  const BlendSwipeScreen({
    super.key,
    required this.onToggleTheme,
    required this.groupId,
  });

  final VoidCallback onToggleTheme;
  final String groupId;

  @override
  ConsumerState<BlendSwipeScreen> createState() => _BlendSwipeScreenState();
}

class _BlendSwipeScreenState extends ConsumerState<BlendSwipeScreen> {
  final _socket = BlendSocketService();
  int _index = 0;
  Offset _dragOffset = Offset.zero;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  Future<void> _connectSocket() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    await _socket.joinBlend(
      groupId: widget.groupId,
      userId: user.id,
      userName: user.name.isNotEmpty ? user.name : 'You',
    );
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _submitSwipe(ProductModel product, SwipeType type) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.recordBlendSwipe(
        groupId: widget.groupId,
        productId: product.id,
        swipeType: swipeTypeToApi(type),
      );
      _socket.sendSwipe(
        groupId: widget.groupId,
        productId: product.id,
        userId: user.id,
        userName: user.name.isNotEmpty ? user.name : 'You',
        swipeType: type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    friendlyErrorMessage(e),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _index += 1;
          _dragOffset = Offset.zero;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: productsAsync.when(
          loading: () => Column(
            children: [
              AppTopBar(
                leading: Icons.arrow_back_rounded,
                trailing: Icons.emoji_events_outlined,
                onLeadingPressed: () => context.pop(),
                onToggleTheme: widget.onToggleTheme,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _SwipeCardSkeleton(),
                ),
              ),
            ],
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(friendlyErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(productsProvider(null)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (products) {
            if (products.isEmpty) {
              return Center(
                child: FriendlyEmptyState(
                  title: 'No products to swipe',
                  message:
                      'The product catalog is being updated. Check back soon.',
                  icon: Icons.inventory_2_outlined,
                  onActionPressed: () => ref.invalidate(productsProvider(null)),
                  actionLabel: 'Retry',
                ),
              );
            }

            if (_index >= products.length) {
              return _FinishedView(
                onToggleTheme: widget.onToggleTheme,
                groupId: widget.groupId,
                onViewResults: () {
                  context.push(AppRoutes.blendResults, extra: widget.groupId);
                },
              );
            }

            final product = products[_index];
            final progress = (_index + 1) / products.length;

            return Column(
              children: [
                AppTopBar(
                  leading: Icons.arrow_back_rounded,
                  trailing: Icons.emoji_events_outlined,
                  onLeadingPressed: () => context.pop(),
                  onTrailingPressed: () {
                    context.push(AppRoutes.blendResults, extra: widget.groupId);
                  },
                  onToggleTheme: widget.onToggleTheme,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Swipe picks',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text(
                        '${_index + 1} of ${products.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() => _dragOffset += details.delta);
                      },
                      onPanEnd: (details) {
                        if (_dragOffset.dx > 120) {
                          _submitSwipe(product, SwipeType.like);
                        } else if (_dragOffset.dx < -120) {
                          _submitSwipe(product, SwipeType.dislike);
                        } else if (_dragOffset.dy < -120) {
                          _submitSwipe(product, SwipeType.love);
                        } else {
                          setState(() => _dragOffset = Offset.zero);
                        }
                      },
                      child: Transform.translate(
                        offset: _dragOffset,
                        child: Transform.rotate(
                          angle: _dragOffset.dx * 0.001,
                          child: _SwipeCard(product: product),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SwipeButton(
                        icon: Icons.close_rounded,
                        color: Colors.redAccent,
                        label: 'Pass',
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitSwipe(product, SwipeType.dislike),
                      ),
                      _SwipeButton(
                        icon: Icons.favorite_rounded,
                        color: Colors.pinkAccent,
                        label: 'Love',
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitSwipe(product, SwipeType.love),
                      ),
                      _SwipeButton(
                        icon: Icons.thumb_up_alt_rounded,
                        color: Colors.green,
                        label: 'Like',
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitSwipe(product, SwipeType.like),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.15 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          size: 80,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        size: 80,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
            ),
          ),
          // Details section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.brand != null && product.brand!.isNotEmpty) ...[
                    Text(
                      product.brand!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (product.articleType != null &&
                      product.articleType!.isNotEmpty) ...[
                    Text(
                      product.articleType!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    product.formattedPrice,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (product.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          product.rating!.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeButton extends StatelessWidget {
  const _SwipeButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    required this.onToggleTheme,
    required this.groupId,
    required this.onViewResults,
  });

  final VoidCallback onToggleTheme;
  final String groupId;
  final VoidCallback onViewResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AppTopBar(
          leading: Icons.arrow_back_rounded,
          trailing: Icons.check_circle_outline_rounded,
          onLeadingPressed: () => context.pop(),
          onToggleTheme: onToggleTheme,
        ),
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.celebration_rounded,
            size: 44,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'You\'re done swiping!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check the group results when everyone finishes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onViewResults,
              child: const Text('View Blend Results'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwipeCardSkeleton extends StatelessWidget {
  const _SwipeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: LoadingSkeletonShimmer(
              height: double.infinity,
              radius:
                  0, // Top border radius handled by card shape, we will clip
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingSkeletonShimmer(height: 24, width: 200, radius: 4),
                  const SizedBox(height: 12),
                  LoadingSkeletonShimmer(height: 14, width: 120, radius: 4),
                  const SizedBox(height: 16),
                  LoadingSkeletonShimmer(height: 18, width: 80, radius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
