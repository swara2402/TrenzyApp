import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/models/group_message.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/auth_provider.dart' as auth_p;
import 'package:trenzy/services/blend_socket_service.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlendChatScreen extends ConsumerStatefulWidget {
  const BlendChatScreen({super.key});

  @override
  ConsumerState<BlendChatScreen> createState() => _BlendChatScreenState();
}

class _BlendChatScreenState extends ConsumerState<BlendChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<GroupMessage> _messages = [];
  final Set<int> _pendingMessageIds = {};
  int _tempIdCounter = 0;
  bool _isLoading = true;
  String? _groupId;
  String? _groupIdFromRoute;
  StreamSubscription<GroupMessage>? _messageSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final params = GoRouterState.of(context).uri.queryParameters;
    final gid = params['groupId'];
    if (gid != null && gid != _groupIdFromRoute) {
      _groupIdFromRoute = gid;
      _groupId = gid;
      // Join the blend over the socket FIRST so chat is live + persisted.
      // sendMessage() below additionally self-heals a missed join, but doing
      // it on load makes the room membership present for the whole session.
      final user = ref.read(auth_p.authProvider).valueOrNull;
      BlendSocketService.instance.joinBlend(
        groupId: gid,
        userId: user?.id ?? '',
        userName: user?.name ?? '',
      );
      _loadMessages();
      _listenForMessages();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenForMessages() {
    _messageSub?.cancel();
    _messageSub = BlendSocketService.instance.messageStream.listen((msg) {
      if (msg.groupId == _groupId && mounted) {
        // A real server message never repeats its id — dedupe on that only.
        final alreadyPresent = _messages.any((m) => m.id == msg.id);
        if (alreadyPresent) return;
        setState(() {
          // Replace the optimistic bubble for THIS message with the
          // server-confirmed copy (matching pending temp by sender+text+time).
          final tempIndex = _messages.indexWhere(
            (m) =>
                _pendingMessageIds.contains(m.id) &&
                m.senderId == msg.senderId &&
                m.message == msg.message &&
                msg.createdAt.difference(m.createdAt).abs() <
                    const Duration(seconds: 10),
          );
          if (tempIndex >= 0) {
            _pendingMessageIds.remove(_messages[tempIndex].id);
            _messages[tempIndex] = msg;
          } else {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    if (_groupId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getGroupMessages(groupId: _groupId!);
      final msgs = (data['messages'] as List<dynamic>? ?? [])
          .map((m) => GroupMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _groupId == null) return;

    final user = ref.read(auth_p.authProvider).valueOrNull;
    final userId = user?.id ?? '';
    final userName = user?.name ?? 'Guest';

    BlendSocketService.instance.sendMessage(
      groupId: _groupId!,
      userId: userId,
      userName: userName,
      message: text,
    );

    final tempId = -DateTime.now().millisecondsSinceEpoch - (_tempIdCounter++);
    setState(() {
      _pendingMessageIds.add(tempId);
      _messages.add(GroupMessage(
        id: tempId,
        groupId: _groupId!,
        senderId: userId,
        senderName: userName,
        message: text,
        createdAt: DateTime.now(),
      ));
    });

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(auth_p.authProvider).valueOrNull;
    final myId = user?.id ?? '';

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: context.trenzyColors.background.withValues(alpha: 0.8),
        elevation: 0,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [context.trenzyColors.primary, context.trenzyColors.emerald],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: context.trenzyColors.graphite,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.emerald,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: context.trenzyColors.emerald.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _groupId != null ? 'Blend ${_groupId!.substring(0, _groupId!.length > 8 ? 8 : _groupId!.length)}...' : 'Blend Chat',
                    style: TextStyle(
                      color: context.trenzyColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Blend Chat',
                    style: TextStyle(
                      color: context.trenzyColors.mutedFg,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: context.trenzyColors.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.trenzyColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(Icons.more_vert, color: context.trenzyColors.mutedFg, size: 18),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.trenzyColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSay hello to your blend!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == myId;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(GroupMessage msg, bool isMe) {
    if (msg.attachedProductId != null) {
      return _buildProductMessage(msg, isMe);
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                    color: context.trenzyColors.primary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMe ? null : context.trenzyColors.graphite,
                gradient: isMe ? GlassGradients.primary : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: context.trenzyColors.glassBorder),
              ),
              child: Text(
                msg.message,
                style: TextStyle(
                  color: isMe ? context.trenzyColors.primaryFg : context.trenzyColors.foreground,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductMessage(GroupMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.attachedProductImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: msg.attachedProductImage!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 160,
                    color: context.trenzyColors.graphite,
                    child: Center(child: CircularProgressIndicator(color: context.trenzyColors.primary, strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 160,
                    color: context.trenzyColors.graphite,
                    child: Icon(Icons.image_not_supported, color: context.trenzyColors.mutedFg),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.message.isNotEmpty)
                    Text(
                      msg.message,
                      style: TextStyle(color: context.trenzyColors.foreground, fontSize: 13),
                    ),
                  if (msg.message.isNotEmpty) SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          msg.attachedProductTitle ?? '',
                          style: TextStyle(
                            color: context.trenzyColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (msg.attachedProductPrice != null)
                        Text(
                          msg.attachedProductPrice!,
                          style: TextStyle(
                            color: context.trenzyColors.foreground,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        child: Row(
          children: [
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: context.trenzyColors.foreground),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: context.trenzyColors.mutedFg.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GlassGradients.primary,
                boxShadow: [
                  BoxShadow(
                    color: context.trenzyColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.send_rounded, color: context.trenzyColors.primaryFg, size: 18),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
