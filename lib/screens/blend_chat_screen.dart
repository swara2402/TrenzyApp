import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/group_message.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../services/blend_socket_service.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';
import '../router/app_router.dart';

class BlendChatScreen extends ConsumerStatefulWidget {
  const BlendChatScreen({
    super.key,
    required this.groupId,
    required this.onToggleTheme,
  });

  final String groupId;
  final VoidCallback onToggleTheme;

  @override
  ConsumerState<BlendChatScreen> createState() => _BlendChatScreenState();
}

class _BlendChatScreenState extends ConsumerState<BlendChatScreen> {
  final _socket = BlendSocketService();

  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<GroupMessage> _messages = [];

  StreamSubscription<GroupMessage>? _socketMsgSub;
  StreamSubscription<String>? _errorSub;

  bool _isLoading = false;
  AttachedProduct? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    _errorSub = _socket.errorStream.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });

    _socketMsgSub = _socket.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.groupId != widget.groupId) return;
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottom();
    });

    await _socket.joinBlend(
      groupId: widget.groupId,
      userId: user.id,
      userName: user.name.isNotEmpty ? user.name : 'You',
    );

    await _loadInitialHistory();
  }

  Future<void> _loadInitialHistory() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getGroupMessages(
        groupId: widget.groupId,
        limit: 50,
      );

      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final messages = rawMessages
          .whereType<Map>()
          .map((e) => GroupMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
      });

      _scrollToBottom();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showProductPicker() async {
    final productsAsync = ref.read(productsProvider(null).future);
    final allProducts = await productsAsync;
    if (!mounted) return;

    final searchController = TextEditingController();
    final selected = await showDialog<ProductModel>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? allProducts
                : allProducts
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(query) ||
                            (p.brand?.toLowerCase().contains(query) ?? false),
                      )
                      .toList();

            return AlertDialog(
              title: const Text('Attach a product'),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No products found'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                return ListTile(
                                  leading:
                                      p.imageUrl != null &&
                                          p.imageUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            p.imageUrl!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, a, b) =>
                                                const Icon(Icons.shopping_bag),
                                          ),
                                        )
                                      : const Icon(Icons.shopping_bag),
                                  title: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: p.brand != null
                                      ? Text(p.brand!)
                                      : null,
                                  onTap: () => Navigator.pop(dialogContext, p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    if (selected != null && mounted) {
      _attachProduct(selected);
    }
  }

  Future<void> _send() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    _textController.clear();
    final attachment = _pendingAttachment;
    setState(() => _pendingAttachment = null);

    _socket.sendMessage(
      groupId: widget.groupId,
      userId: user.id,
      userName: user.name.isNotEmpty ? user.name : 'You',
      message: text,
      attachedProductId: attachment?.productId,
      attachedProductTitle: attachment?.title,
      attachedProductImage: attachment?.image,
      attachedProductPrice: attachment?.price,
    );

    _scrollToBottom();
  }

  void _attachProduct(ProductModel product) {
    setState(() {
      _pendingAttachment = AttachedProduct(
        productId: product.id,
        title: product.name,
        image: product.imageUrl,
        price: product.formattedPrice,
      );
    });
  }

  @override
  void dispose() {
    _socketMsgSub?.cancel();
    _errorSub?.cancel();
    _socket.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.send_rounded,
              onLeadingPressed: () => context.pop(),
              onTrailingPressed: _send,
              onToggleTheme: widget.onToggleTheme,
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == user?.id;
                      return _MessageBubble(
                        isMe: isMe,
                        senderName: msg.senderName,
                        message: msg.message,
                        timeText: _timeShort(msg.createdAt),
                        attachedProduct: msg.attachedProductId != null
                            ? AttachedProduct(
                                productId: msg.attachedProductId!,
                                title: msg.attachedProductTitle ?? '',
                                image: msg.attachedProductImage,
                                price: msg.attachedProductPrice,
                              )
                            : null,
                      );
                    },
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _Composer(
              controller: _textController,
              onSend: _send,
              onAttachProduct: _showProductPicker,
              onRemoveAttachment: () {
                setState(() => _pendingAttachment = null);
              },
              pendingAttachment: _pendingAttachment,
            ),
          ],
        ),
      ),
    );
  }

  String _timeShort(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.isMe,
    required this.senderName,
    required this.message,
    required this.timeText,
    this.attachedProduct,
  });

  final bool isMe;
  final String senderName;
  final String message;
  final String timeText;
  final AttachedProduct? attachedProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = isMe
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.secondaryContainer.withValues(alpha: 0.35);

    final textColor = isMe
        ? theme.colorScheme.primary
        : theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18).subtract(
                  isMe
                      ? const BorderRadius.only(bottomRight: Radius.circular(6))
                      : const BorderRadius.only(bottomLeft: Radius.circular(6)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 2),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (attachedProduct != null) ...[
                      const SizedBox(height: 8),
                      _ProductCard(product: attachedProduct!),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.labelSmall?.color?.withValues(
                          alpha: 0.75,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final AttachedProduct product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.productDetails,
          extra: ProductDetailsRouteExtra(productId: product.productId),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            if (product.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Image.network(
                  product.image!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.shopping_bag),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.price != null)
                      Text(
                        product.price!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttachedProduct {
  const AttachedProduct({
    required this.productId,
    required this.title,
    this.image,
    this.price,
  });

  final String productId;
  final String title;
  final String? image;
  final String? price;
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttachProduct,
    required this.onRemoveAttachment,
    required this.pendingAttachment,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttachProduct;
  final VoidCallback onRemoveAttachment;
  final AttachedProduct? pendingAttachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingAttachment != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    if (pendingAttachment!.image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          pendingAttachment!.image!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, a, b) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[300],
                            child: const Icon(Icons.shopping_bag, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag, size: 20),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pendingAttachment!.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (pendingAttachment!.price != null)
                            Text(
                              pendingAttachment!.price!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onRemoveAttachment,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: onAttachProduct,
                  icon: Icon(
                    pendingAttachment != null
                        ? Icons.attach_file_rounded
                        : Icons.add_circle_outline_rounded,
                    color: pendingAttachment != null
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  tooltip: 'Attach product',
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: theme.colorScheme.surface.withValues(alpha: 0.7),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
