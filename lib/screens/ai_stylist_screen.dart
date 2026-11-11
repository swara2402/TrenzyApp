import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/api_service_provider.dart';
import '../services/api_service.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';
import '../models/wardrobe_model.dart';
import '../providers/wardrobe_provider.dart';

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
  String _selectedOccasion = 'Everyday';
  String _selectedAesthetic = 'Casual';
  Set<String>? _selectedWardrobeItemIds;
  final List<XFile> _outfitPhotos = <XFile>[];

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
    'Choose one outfit and style the complete look',
    'Choose one saree and match my jewellery',
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
    await _requestStylist(text, addUserMessage: true);
  }

  Future<void> _pickOutfitPhotos() async {
    if (_loading) return;
    final picked = await ImagePicker().pickMultiImage(
      limit: 4,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _outfitPhotos
        ..clear()
        ..addAll(picked.take(4));
    });
  }

  Future<void> _compareOutfitPhotos() async {
    if (_loading || _outfitPhotos.length < 2) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(apiServiceProvider).compareStylistPhotos(
        List<XFile>.from(_outfitPhotos),
        occasion: _selectedOccasion,
        aesthetic: _selectedAesthetic,
        prompt: _controller.text.trim(),
      );
      final winner = (result['winner_option'] as num?)?.toInt();
      if (winner == null || winner < 1 || winner > _outfitPhotos.length) {
        throw StateError('The stylist could not identify a winning photo.');
      }
      final confidence = result['confidence'] == 'close_call'
          ? 'The options were close, so treat this as a gentle recommendation.'
          : 'This option was the stronger visual match to your brief.';
      final reason = result['reason']?.toString() ?? confidence;
      final prompt = 'Compare my uploaded outfit options. The visual comparison selected '
          'option $winner for $_selectedOccasion and $_selectedAesthetic. $reason '
          '$confidence Use this as the base outfit, then complete the look using '
          'matching accessories from my saved wardrobe where available. Be honest '
          'about anything I do not own. Do not claim details that cannot be seen.';
      if (!mounted) return;
      setState(() => _loading = false);
      await _requestStylist(prompt, addUserMessage: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add({
          'role': 'assistant',
          'text': 'I couldn’t compare those photos right now. Please try again with 2–4 clear outfit photos.',
          'products': <Map<String, dynamic>>[],
        });
      });
    }
  }

  Future<void> _retry(String prompt) async {
    if (_loading) return;
    setState(() {
      if (_messages.isNotEmpty && _messages.last['retryPrompt'] == prompt) {
        _messages.removeLast();
      }
    });
    await _requestStylist(prompt, addUserMessage: false);
  }

  String _contextualizePrompt(String prompt) {
    final wardrobe = ref.read(wardrobeProvider).valueOrNull?.items ?? const <WardrobeItem>[];
    final selected = _selectedWardrobeItemIds == null
        ? wardrobe
        : wardrobe.where((item) => _selectedWardrobeItemIds!.contains(item.id)).toList();
    final pieces = selected.take(14).map((item) {
      final details = <String>[item.name];
      if (item.category.trim().isNotEmpty) details.add(item.category.trim());
      if (item.color.trim().isNotEmpty) details.add(item.color.trim());
      if (item.brand.trim().isNotEmpty) details.add(item.brand.trim());
      return details.join(' · ');
    }).join('; ');
    final wardrobeContext = selected.isEmpty
        ? 'No owned wardrobe pieces are selected. Do not claim that a suggested product is already owned.'
        : 'Owned wardrobe item ids: ${selected.map((item) => item.id).join(',')}. Owned wardrobe pieces (prioritize these and do not invent ownership): $pieces.';
    final brief = 'Styling brief: occasion=$_selectedOccasion; aesthetic=$_selectedAesthetic. $wardrobeContext';
    final availablePromptLength = (1900 - brief.length - 2).clamp(200, 1900).toInt();
    final concisePrompt = prompt.length > availablePromptLength
        ? prompt.substring(0, availablePromptLength)
        : prompt;
    return '$concisePrompt\n\n$brief';
  }

  Widget _buildStyleBrief(BuildContext context, List<WardrobeItem> items, bool loading) {
    final c = context.trenzyColors;
    final selectedCount = _selectedWardrobeItemIds == null
        ? items.length
        : items.where((item) => _selectedWardrobeItemIds!.contains(item.id)).length;
    Widget chipRow(List<String> values, String selected, ValueChanged<String> onSelected) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: values.map((value) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(value),
              selected: selected == value,
              onSelected: _loading ? null : (_) => onSelected(value),
              selectedColor: c.primary.withValues(alpha: 0.2),
              labelStyle: GlassTypography.meta(
                fontSize: 10,
                color: selected == value ? c.primary : c.mutedFg,
              ),
              side: BorderSide(color: selected == value ? c.primary : c.glassBorder),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          )).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.graphite.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.tune_rounded, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Text('STYLE BRIEF', style: GlassTypography.meta(fontSize: 10, color: c.primary)),
              const Spacer(),
              Text('$selectedCount/${items.length} closet pieces', style: GlassTypography.meta(fontSize: 9, color: c.mutedFg)),
            ]),
            const SizedBox(height: 5),
            Text('Occasion', style: GlassTypography.meta(fontSize: 10, color: c.mutedFg)),
            chipRow(const ['Everyday', 'College', 'Work', 'Party', 'Travel', 'Date night', 'Formal'], _selectedOccasion,
              (value) => setState(() => _selectedOccasion = value)),
            const SizedBox(height: 2),
            Text('Aesthetic', style: GlassTypography.meta(fontSize: 10, color: c.mutedFg)),
            chipRow(const ['Casual', 'Minimal', 'Streetwear', 'Classic', 'Y2K', 'Boho', 'Old money', 'Sporty'], _selectedAesthetic,
              (value) => setState(() => _selectedAesthetic = value)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.checkroom_rounded, size: 13, color: c.mutedFg),
              const SizedBox(width: 5),
              Expanded(child: Text('Use pieces from my wardrobe', style: GlassTypography.meta(fontSize: 10, color: c.foreground))),
              if (loading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.primary))
              else if (items.isEmpty)
                TextButton(
                  onPressed: _loading ? null : () => context.push(AppRoutes.addItem),
                  child: const Text('Add pieces', style: TextStyle(fontSize: 10)),
                )
              else
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _selectedWardrobeItemIds = null),
                  child: Text('Select all', style: TextStyle(fontSize: 10, color: c.primary)),
                ),
            ]),
            if (items.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: items.map((item) {
                  final selected = _selectedWardrobeItemIds == null || _selectedWardrobeItemIds!.contains(item.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: selected,
                      onSelected: _loading ? null : (value) => setState(() {
                        final next = _selectedWardrobeItemIds == null
                            ? items.map((entry) => entry.id).toSet()
                            : Set<String>.from(_selectedWardrobeItemIds!);
                        if (value) { next.add(item.id); } else { next.remove(item.id); }
                        _selectedWardrobeItemIds = next;
                      }),
                      selectedColor: c.primary.withValues(alpha: 0.16),
                      checkmarkColor: c.primary,
                      labelStyle: GlassTypography.meta(fontSize: 9, color: selected ? c.primary : c.mutedFg),
                      side: BorderSide(color: selected ? c.primary.withValues(alpha: 0.55) : c.glassBorder),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                    ),
                  );
                }).toList()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestStylist(
    String text, {
    required bool addUserMessage,
  }) async {
    if (text.trim().isEmpty || _loading) return;

    setState(() {
      if (addUserMessage) {
        _messages.add({'role': 'user', 'text': text, 'products': []});
      }
      _loading = true;
    });
    _scrollToBottom();

    try {
      final result = await ref
          .read(apiServiceProvider)
          .aiStylistChat(
            message: _contextualizePrompt(text),
            conversationId: _conversationId,
            persona: _selectedPersona,
          );
      _conversationId = (result['conversation_id'] as num?)?.toInt();

      final responseText =
          (result['message'] ?? result['reply'] ?? result['response'])
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
                'I’m having trouble reaching the stylist right now. Check your connection and try again.',
            'products': [],
            'retryPrompt': text,
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
    final wardrobeAsync = ref.watch(wardrobeProvider);
    final wardrobeItems = wardrobeAsync.valueOrNull?.items ?? const <WardrobeItem>[];

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

          _buildStyleBrief(context, wardrobeItems, wardrobeAsync.isLoading),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: c.graphite.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: c.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.photo_library_outlined, size: 16, color: c.primary),
                    const SizedBox(width: 7),
                    Expanded(child: Text('Compare outfit photos', style: GlassTypography.meta(fontSize: 11, color: c.foreground))),
                    Text('${_outfitPhotos.length}/4', style: GlassTypography.meta(fontSize: 10, color: c.mutedFg)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Upload 2–4 options. Photos are compared for this request and are not saved by the comparison service.',
                    style: GlassTypography.meta(fontSize: 9, color: c.mutedFg)),
                  if (_outfitPhotos.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _outfitPhotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_outfitPhotos[index].path),
                            width: 64,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(children: [
                    TextButton.icon(
                      onPressed: _loading ? null : _pickOutfitPhotos,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                      label: Text(_outfitPhotos.isEmpty ? 'Add photos' : 'Replace photos'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _loading || _outfitPhotos.length < 2 ? null : _compareOutfitPhotos,
                      child: const Text('Choose my look'),
                    ),
                  ]),
                ],
              ),
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
                        if (!isUser && m['retryPrompt'] is String) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _retry(m['retryPrompt'] as String),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Try again'),
                              style: TextButton.styleFrom(
                                foregroundColor: c.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
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
