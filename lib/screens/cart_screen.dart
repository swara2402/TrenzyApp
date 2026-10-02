import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../providers/api_service_provider.dart';
import '../models/decision_flow.dart' as df;
import '../models/cart_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/glass_theme.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(GlassSpacing.lg, 8, GlassSpacing.lg, 0),
              child: Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  SizedBox(width: 8),
                  DisplayText(
                    'Decision List ($totalItems)',
                    fontSize: 20,
                    weight: FontWeight.w600,
                  ),
                  Spacer(),
                  if (cartItems.isNotEmpty)
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).clearCart(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.crimson.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'REMOVE ALL',
                          style: GlassTypography.body(
                            fontSize: 10,
                            color: context.trenzyColors.crimson,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Delivery estimate banner
            if (cartItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.trenzyColors.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.trenzyColors.emerald.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: context.trenzyColors.emerald),
                    SizedBox(width: 8),
                    Text(
                      'Orders are fulfilled by our partner stores',
                      style: GlassTypography.body(
                        fontSize: 12,
                        color: context.trenzyColors.emerald,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: cartItems.isEmpty
                  ? Center(
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
                                border: Border.all(
                                  color: context.trenzyColors.glassBorder,
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.trenzyColors.primary.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  Icons.bookmark_outline_rounded,
                                  size: 36,
                                  color: context.trenzyColors.primary,
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            DisplayText('Nothing saved yet', fontSize: 20, weight: FontWeight.w700),
                            SizedBox(height: 8),
                            Text(
                              'Tap Save on any product to shortlist it here.\nWhen you\u2019re ready, you\u2019ll shop it on the partner store.',
                              style: GlassTypography.body(
                                color: context.trenzyColors.mutedFg.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            GlowButton(
                              label: 'Explore Styles',
                              onTap: () => context.go(AppRoutes.discover),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final cartItem = cartItems[index];
                        return Dismissible(
                          key: ValueKey(cartItem.product.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => ref.read(cartProvider.notifier).removeFromCart(cartItem.product),
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.trenzyColors.crimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(Icons.delete_outline_rounded, color: context.trenzyColors.crimson, size: 26),
                          ),
                          child: _CartItem(
                            cartItem: cartItem,
                            onRemove: () => ref.read(cartProvider.notifier).removeFromCart(cartItem.product),
                            onIncrement: () => ref.read(cartProvider.notifier).incrementQuantity(cartItem.product.id),
                            onDecrement: () => ref.read(cartProvider.notifier).decrementQuantity(cartItem.product.id),
                          ),
                        );
                      },
                    ),
            ),
            if (cartItems.isNotEmpty) _CartSummary(
              subtotal: subtotal,
              itemCount: totalItems,
              items: cartItems,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItem({
    required this.cartItem,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final product = cartItem.product;
    final unitPrice = product.price ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassContainer(
        radius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl ?? 'https://placehold.co/400x600/1a1a2e/666.png?text=No+Image',
                width: 90,
                height: 110,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: 90,
                  height: 110,
                  color: Colors.grey[900],
                  child: Icon(Icons.image_outlined, color: context.trenzyColors.mutedFg, size: 24),
                ),
                errorWidget: (_, _, _) => Container(
                  width: 90,
                  height: 110,
                  color: Colors.grey[900],
                  child: Icon(Icons.broken_image, color: context.trenzyColors.mutedFg, size: 24),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GlassTypography.display(
                      fontSize: 14,
                      weight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (product.effectiveBrand.isNotEmpty)
                    Text(
                      product.effectiveBrand.toUpperCase(),
                      style: GlassTypography.body(
                        fontSize: 10,
                        color: context.trenzyColors.mutedFg,
                        weight: FontWeight.w600,
                      ),
                    ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '\u20B9${(unitPrice * cartItem.quantity).toStringAsFixed(0)}',
                        style: GlassTypography.display(
                          fontSize: 16,
                          weight: FontWeight.w800,
                          color: context.trenzyColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _MiniQuantitySelector(
                        quantity: cartItem.quantity,
                        onDecrement: cartItem.quantity > 1 ? onDecrement : null,
                        onIncrement: onIncrement,
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.trenzyColors.crimson.withValues(alpha: 0.1),
                            border: Border.all(color: context.trenzyColors.crimson.withValues(alpha: 0.2)),
                          ),
                          child: Icon(Icons.delete_outline_rounded, size: 16, color: context.trenzyColors.crimson),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniQuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _MiniQuantitySelector({
    required this.quantity,
    this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.trenzyColors.glassBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: Icon(Icons.remove_rounded, size: 16, color: onDecrement == null ? context.trenzyColors.mutedFg.withValues(alpha: 0.3) : context.trenzyColors.foreground),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: context.trenzyColors.glassBorder.withValues(alpha: 0.2)),
              ),
            ),
            child: Text(
              '$quantity',
              style: GlassTypography.body(fontSize: 13, weight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: Icon(Icons.add_rounded, size: 16, color: context.trenzyColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends ConsumerStatefulWidget {
  final double subtotal;
  final int itemCount;
  final List<CartItem> items;

  const _CartSummary({
    required this.subtotal,
    required this.itemCount,
    required this.items,
  });

  @override
  ConsumerState<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends ConsumerState<_CartSummary> {
  bool _openingPartner = false;

  Future<void> _shopOnPartner() async {
    if (_openingPartner) return;
    if (widget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your decision list is empty.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _openingPartner = true);
    try {
      final api = ref.read(apiServiceProvider);
      // Shop the most recently saved item's partner store.
      final item = widget.items.last;
      final product = item.product;
      final link = await api.trackAffiliateClick(product.id);
      final uri = link != null
          ? Uri.tryParse(link)
          : Uri.parse(
              'https://www.google.com/search?q=${Uri.encodeComponent('${product.name} ${product.effectiveBrand}')}');
      var launched = false;
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          launched = false;
        }
      }
      if (!launched && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the partner store.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the partner store.')),
      );
    } finally {
      if (mounted) setState(() => _openingPartner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = 0.0;
    final discount = 0.0;
    final total = widget.subtotal + delivery - discount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        border: Border(
          top: BorderSide(color: context.trenzyColors.glassBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Coupon section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.trenzyColors.glass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.trenzyColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number_rounded, size: 18, color: context.trenzyColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Apply Coupon',
                      style: GlassTypography.body(fontSize: 13, weight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: context.trenzyColors.mutedFg),
                ],
              ),
            ),
            SizedBox(height: 14),
            // Price breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Price (${widget.itemCount} items)', style: GlassTypography.body(fontSize: 13)),
                Text(
                  '\u20B9${widget.subtotal.toStringAsFixed(0)}',
                  style: GlassTypography.body(fontSize: 13),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount', style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg)),
                Text(
                  '-\u20B9${discount.toStringAsFixed(0)}',
                  style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.emerald),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Delivery', style: GlassTypography.body(fontSize: 13, color: context.trenzyColors.mutedFg)),
                Text(
                  'Partner store',
                  style: GlassTypography.body(
                    fontSize: 13,
                    color: context.trenzyColors.emerald,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.trenzyColors.primary.withValues(alpha: 0.3),
                    context.trenzyColors.glassBorder,
                    context.trenzyColors.primary.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DisplayText('Total', fontSize: 16, weight: FontWeight.w800),
                Text(
                  '\u20B9${total.toStringAsFixed(0)}',
                  style: GlassTypography.display(fontSize: 16, weight: FontWeight.w800, color: context.trenzyColors.primary),
                ),
              ],
            ),
            SizedBox(height: 14),
            if (widget.items.length >= 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlowButton(
                  label: 'DECIDE BETWEEN ${widget.itemCount} ITEMS',
                  icon: Icons.compare_arrows,
                  onTap: () {
                    final options = widget.items.map((item) {
                      return df.SuggestionOption(
                        product: item.product,
                        matchScore: 0,
                      );
                    }).toList();
                    context.push(
                      AppRoutes.decision,
                      extra: df.DecisionRouteExtra(
                        query: 'Compare ${widget.itemCount} items',
                        selectedOptions: options,
                        reactions: const [],
                      ),
                    );
                  },
                  width: double.infinity,
                ),
              ),
            GlowButton(
              label: 'CHECKOUT SECURELY · ₹${total.toStringAsFixed(0)}',
              icon: Icons.lock_outline_rounded,
              onTap: () => context.push(AppRoutes.checkout),
              width: double.infinity,
            ),
            SizedBox(height: 8),
            GlowButton(
              label: _openingPartner ? 'OPENING PARTNER STORE...' : 'SHOP ON PARTNER',
              icon: Icons.open_in_new,
              loading: _openingPartner,
              onTap: _shopOnPartner,
              width: double.infinity,
            ),
            SizedBox(height: 8),
            Text(
              'Every item is bought securely on the partner store. Trenzy just helps you decide.',
              style: GlassTypography.body(
                fontSize: 11,
                color: context.trenzyColors.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}