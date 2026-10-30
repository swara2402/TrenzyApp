import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/api_service_provider.dart';
import '../services/api_service.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

class AiStylistScreen extends ConsumerStatefulWidget {
  const AiStylistScreen({super.key});

  @override
  ConsumerState<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends ConsumerState<AiStylistScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <Map<String, dynamic>>[];
  int? _conversationId;
  bool _loading = false;
  String _selectedPersona = 'everyday';

  static const _personas = <String, String>{
    'everyday': 'Everyday',
    'minimalist': 'Minimalist',
    'streetwear': 'Streetwear',
    'trendsetter': 'Trendsetter',
  };

  final List<String> _quickPrompts = const [
    'Casual weekend look',
    'Summer party dress',
    'Minimalist office wear',
    'Sneaker pairings',
  ];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add({
      'role': 'assistant',
      'text':
          'Hey there! I’m your Trenzy AI Stylist. Ask me for outfit ideas, styling advice, color pairings, or product recommendations.',
      'products': <Map<String, dynamic>>[],
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? promptText]) async {
    final text = promptText ?? _controller.text.trim();
    if (text.isEmpty || _loading) return;
    if (promptText == null) _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'products': []});
      _loading = true;
    });
    _scrollToBottom();

    try {
      final result = await ref
          .read(apiServiceProvider)
          .aiStylistChat(message: text, conversationId: _conversationId, persona: _selectedPersona);
      _conversationId = (result['conversation_id'] as num?)?.toInt();

      final responseText = (result['message'] ?? result['reply'] ?? result['response'])
          ?.toString()
          .trim();
      final rawProducts = result['mentioned_products'] ?? result['products'];
      final products = rawProducts is List
          ? rawProducts.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': (responseText == null || responseText.isEmpty)
                ? 'Tell me the occasion, your preferred style, and what pieces you have. I’ll help you put together an outfit.'
                : responseText,
            'products': products,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text':
                'I’m having trouble reaching the stylist right now. Check your connection and tap to try again.',
            'products': [],
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.foreground,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 48,
        toolbarHeight: 72,
        leading: const GlassBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AI Stylist',
              style: GlassTypography.display(
                fontSize: 20,
                weight: FontWeight.w700,
                color: c.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Your personal styling assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassTypography.meta(fontSize: 11, color: c.mutedFg),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Select a distinct stylist persona before chatting.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(
              children: _personas.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedPersona == entry.key,
                  onSelected: _loading ? null : (_) => setState(() => _selectedPersona = entry.key),
                  selectedColor: c.primary.withValues(alpha: 0.22),
                  labelStyle: GlassTypography.meta(fontSize: 11, color: _selectedPersona == entry.key ? c.primary : c.mutedFg),
                  side: BorderSide(color: _selectedPersona == entry.key ? c.primary : c.glassBorder),
                ),
              )).toList(),
            ),
          ),

          // Quick prompts bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _quickPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      prompt,
                      style: GlassTypography.meta(
                        fontSize: 11,
                        color: c.primary,
                      ),
                    ),
                    backgroundColor: c.primary.withValues(alpha: 0.12),
                    side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: _loading ? null : () => _send(prompt),
                  ),
                );
              }).toList(),
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                final text = m['text'] as String? ?? '';
                final products = (m['products'] as List<dynamic>?) ?? [];

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser ? c.primary : c.graphite,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                      border: Border.all(
                        color: isUser
                            ? c.primary
                            : c.foreground.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: GlassTypography.body(
                            fontSize: 14,
                            color: isUser ? c.primaryFg : c.foreground,
                            height: 1.45,
                          ),
                        ),
                        if (products.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ...products.map((p) {
                            final pid = p['id']?.toString() ?? '';
                            final name = p['name']?.toString() ?? 'Product';
                            final rawImg = p['image_url']?.toString();
                            final resolvedImg =
                                ApiService.resolveImageUrl(rawImg) ??
                                rawImg ??
                                '';
                            final price = p['price']?.toString() ?? '';

                            return GestureDetector(
                              onTap: pid.isNotEmpty
                                  ? () => context.push(
                                      AppRoutes.productDetailsFor(pid),
                                    )
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: c.background.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    if (resolvedImg.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: resolvedImg,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            width: 40,
                                            height: 40,
                                            color: c.graphite,
                                            child: Icon(
                                              Icons.checkroom,
                                              size: 20,
                                              color: c.mutedFg,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GlassTypography.body(
                                              fontSize: 12,
                                              weight: FontWeight.w600,
                                              color: c.foreground,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (price.isNotEmpty)
                                            Text(
                                              '₹$price',
                                              style: GlassTypography.body(
                                                fontSize: 11,
                                                color: c.primary,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: c.mutedFg,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                backgroundColor: c.graphite,
                color: c.primary,
                minHeight: 3,
              ),
            ),

          // Input field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.graphite,
                border: Border(top: BorderSide(color: c.glassBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      style: GlassTypography.body(color: c.foreground),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask your stylist…',
                        hintStyle: GlassTypography.body(color: c.mutedFg),
                        filled: true,
                        fillColor: c.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: c.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: c.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: c.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loading ? null : () => _send(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _loading ? c.mutedFg : c.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: c.primaryFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
