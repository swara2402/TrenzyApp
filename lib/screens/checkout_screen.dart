import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/cart_model.dart';
import '../providers/api_service_provider.dart';
import '../providers/cart_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

enum _CheckoutPhase { review, processing, payment, success }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  _CheckoutPhase _phase = _CheckoutPhase.review;
  String _orderId = '';
  String _paymentCheckoutUrl = '';
  bool _finalized = false;

  Future<void> _placeOrder(List<CartItem> items, double total) async {
    if (items.isEmpty) return;
    setState(() => _phase = _CheckoutPhase.processing);
    try {
      final api = ref.read(apiServiceProvider);
      final amountPaise = (total * 100).round();
      final order = await api.createPaymentOrder(amountPaise: amountPaise);
      final orderId =
          (order['razorpay_order_id'] ?? order['id'] ?? '').toString();
      if (orderId.isEmpty) {
        throw StateError('Could not create payment order');
      }

      final simulation = order['simulation'] as bool? ?? true;
      if (simulation) {
        final verified = await api.verifyPayment(
          razorpayOrderId: orderId,
          razorpayPaymentId: 'sim_pay_${DateTime.now().millisecondsSinceEpoch}',
          razorpaySignature: 'sim_signature',
        );
        final status = verified['status']?.toString() ?? 'completed';
        if (status != 'completed') {
          throw StateError(
              verified['message']?.toString() ?? 'Payment not completed');
        }
        final finalOrderId = verified['order_id']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _orderId = finalOrderId.isNotEmpty ? finalOrderId : orderId;
            _finalized = true;
            _phase = _CheckoutPhase.success;
          });
        }
        final notifier = ref.read(cartProvider.notifier);
        await notifier.refresh();
      } else {
        if (mounted) {
          setState(() {
            _orderId = orderId;
            _phase = _CheckoutPhase.payment;
          });
        }
        final checkoutUrl = (order['checkout_url'] ?? '').toString();
        if (checkoutUrl.isNotEmpty && mounted) {
          setState(() {
            _paymentCheckoutUrl = checkoutUrl;
            _orderId = orderId;
            _phase = _CheckoutPhase.payment;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phase = _CheckoutPhase.review);
        GlassToast.error(
            context, 'Could not complete checkout. Please try again.');
      }
    }
  }

  Future<void> _pollPaymentStatus(String orderId) async {
    if (_phase == _CheckoutPhase.processing) return;
    setState(() => _phase = _CheckoutPhase.processing);
    try {
      final api = ref.read(apiServiceProvider);
      Map<String, dynamic>? status;
      for (var attempt = 0; attempt < 6; attempt++) {
        status = await api.getPaymentOrderStatus(razorpayOrderId: orderId);
        final s = status['status']?.toString() ?? '';
        if (s == 'completed') break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      final s = status?['status']?.toString() ?? '';
      if (s == 'completed') {
        final finalOrderId = status?['order_id']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _orderId = finalOrderId.isNotEmpty ? finalOrderId : orderId;
            _finalized = true;
            _phase = _CheckoutPhase.success;
          });
        }
        final notifier = ref.read(cartProvider.notifier);
        await notifier.refresh();
      } else {
        if (mounted) {
          setState(() => _phase = _CheckoutPhase.payment);
          GlassToast.info(
            context,
            'Payment confirmation can take a minute. Your order is safe - '
            'check back shortly.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _CheckoutPhase.payment);
        GlassToast.error(context, 'Could not check payment status. Try again.');
      }
    }
  }

  Future<void> _confirmAndFinalize() async {
    await _pollPaymentStatus(_orderId);
  }



  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider);
    final total = ref.watch(cartSubtotalProvider);

    if (_phase == _CheckoutPhase.success) {
      return _buildSuccess();
    }

    if (_phase == _CheckoutPhase.payment) {
      return _buildPaymentPending(items);
    }

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(GlassSpacing.lg, 8, GlassSpacing.lg, 0),
              child: Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  const SizedBox(width: 8),
                  DisplayText('Checkout', fontSize: 20, weight: FontWeight.w600),
                ],
              ),
            ),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Your decision list is empty',
                    style:
                        GlassTypography.body(color: context.trenzyColors.mutedFg),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(GlassSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final product = item.product;
                    return Container(
                      margin: const EdgeInsets.only(bottom: GlassSpacing.sm),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.glass,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: context.trenzyColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 52,
                              height: 64,
                              child: CachedNetworkImage(
                                      imageUrl: product.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.effectiveBrand,
                                  style: GlassTypography.body(
                                    fontSize: 11,
                                    color: context.trenzyColors.mutedFg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GlassTypography.body(
                                      fontSize: 13,
                                      weight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Qty ${item.quantity}',
                                  style: GlassTypography.body(
                                      fontSize: 11,
                                      color: context.trenzyColors.mutedFg),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.totalPrice.toStringAsFixed(0)}',
                            style: GlassTypography.body(
                                fontSize: 13, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(GlassSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Price (${items.length} items)',
                            style: GlassTypography.body(fontSize: 13)),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: GlassTypography.body(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery',
                            style: GlassTypography.body(
                                fontSize: 13,
                                color: context.trenzyColors.mutedFg)),
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
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DisplayText('Total', fontSize: 16, weight: FontWeight.w800),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: GlassTypography.display(
                            fontSize: 16,
                            weight: FontWeight.w800,
                            color: context.trenzyColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GlowButton(
                      label: _phase == _CheckoutPhase.processing
                          ? 'PROCESSING ORDER...'
                          : 'PLACE ORDER · ₹${total.toStringAsFixed(0)}',
                      icon: Icons.lock_outline_rounded,
                      loading: _phase == _CheckoutPhase.processing,
                      onTap: () => _placeOrder(items, total),
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPending(List<CartItem> items) {
    // Add in-app WebView for real payment checkout to improve user experience
    if (_orderId.isNotEmpty && !_finalized && _paymentCheckoutUrl.isNotEmpty) {
       final controller = WebViewController()
         ..setJavaScriptMode(JavaScriptMode.unrestricted)
         ..setNavigationDelegate(
           NavigationDelegate(
             onPageFinished: (String url) {
               // Check if we've reached the success/failure page
               if (url.contains('/payment/success') || url.contains('/payment/failure')) {
                 _pollPaymentStatus(_orderId);
               }
             },
             onWebResourceError: (WebResourceError error) {
               if (mounted) {
                 GlassToast.error(context, 'Payment page failed to load. Please try again.');
               }
             },
           ),
         )
         ..loadRequest(Uri.parse(_paymentCheckoutUrl));
       
       return Scaffold(
         backgroundColor: context.trenzyColors.background,
         appBar: AppBar(
           title: const Text('Complete Payment'),
           backgroundColor: context.trenzyColors.background,
           automaticallyImplyLeading: false,
         ),
         body: WebViewWidget(controller: controller),
       );
     }
    
    // Fallback to original payment pending UI if no WebView is needed
    final amount = items.fold<double>(0, (s, it) => s + it.totalPrice);
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(GlassSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  const SizedBox(width: 8),
                  DisplayText('Checkout', fontSize: 20, weight: FontWeight.w600),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: context.trenzyColors.primary,
              ),
              const SizedBox(height: 20),
              DisplayText(
                'Complete your payment',
                fontSize: 20,
                weight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Secure payment is being processed in-app. '
                'Amount ₹${amount.toStringAsFixed(0)} for order $_orderId.',
                textAlign: TextAlign.center,
                style: GlassTypography.body(
                    color: context.trenzyColors.mutedFg, fontSize: 13),
              ),
              const SizedBox(height: 28),
              GlowButton(
                label: 'I HAVE COMPLETED PAYMENT',
                icon: Icons.check_circle_outline_rounded,
                loading: _phase == _CheckoutPhase.processing,
                onTap: () => _confirmAndFinalize(),
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _phase == _CheckoutPhase.processing
                    ? null
                    : () => context.go(AppRoutes.home),
                child: Text(
                  'Return to store',
                  style: TextStyle(color: context.trenzyColors.mutedFg),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(GlassSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 72, color: context.trenzyColors.emerald),
                const SizedBox(height: 18),
                DisplayText(
                  _finalized ? 'Order placed' : 'Payment received',
                  fontSize: 22,
                  weight: FontWeight.w800,
                ),
                const SizedBox(height: 8),
                Text(
                  _finalized
                      ? 'Order $_orderId has been placed successfully.'
                      : 'Your payment details are being confirmed. '
                          'Check your orders shortly.',
                  textAlign: TextAlign.center,
                  style: GlassTypography.body(
                      color: context.trenzyColors.mutedFg, fontSize: 13),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'CONTINUE SHOPPING',
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => context.go(AppRoutes.home),
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}