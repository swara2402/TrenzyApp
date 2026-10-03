import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/direct_message.dart';
import '../providers/api_service_provider.dart';
import '../providers/auth_provider.dart' as auth_p;
import '../theme/glass_theme.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key, required this.friendFirebaseUid, required this.friendName});
  final String friendFirebaseUid;
  final String friendName;
  @override ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<DirectMessage> _messages = [];
  bool _loading = true, _sending = false;

  @override void initState() { super.initState(); _loadMessages(); }
  @override void dispose() { _controller.dispose(); _scrollController.dispose(); super.dispose(); }

  Future<void> _loadMessages() async {
    try {
      final data = await ref.read(apiServiceProvider).getDirectMessages(friendFirebaseUid: widget.friendFirebaseUid);
      final rows = (data['messages'] as List<dynamic>? ?? [])
          .map((row) => DirectMessage.fromJson(Map<String, dynamic>.from(row as Map))).toList();
      if (!mounted) return;
      setState(() { _messages..clear()..addAll(rows); _loading = false; });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load chat: $e')));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(auth_p.authProvider).valueOrNull;
    if ((user?.id ?? '').isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final data = await ref.read(apiServiceProvider).sendDirectMessage(toFirebaseUid: widget.friendFirebaseUid, message: text);
      final raw = data['message'];
      if (raw is Map) {
        setState(() => _messages.add(DirectMessage.fromJson(Map<String, dynamic>.from(raw))));
      } else { await _loadMessages(); }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message not sent: $e')));
      }
    } finally { if (mounted) setState(() => _sending = false); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    final myUid = ref.watch(auth_p.authProvider).valueOrNull?.id ?? '';
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: colors.foreground), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: colors.primary.withValues(alpha: 0.18),
            child: Text(widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Text(widget.friendName, style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w700)),
        ]),
      ),
      body: Column(children: [
        Expanded(child: _loading ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _messages.isEmpty ? Center(child: Text('No messages yet.\nSay hello to your friend!',
              textAlign: TextAlign.center, style: TextStyle(color: colors.mutedFg)))
          : ListView.builder(
              controller: _scrollController, padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message.senderFirebaseUid == myUid;
                return Align(alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: isMine ? colors.primary : colors.graphite,
                      borderRadius: BorderRadius.circular(18),
                      border: isMine ? null : Border.all(color: colors.glassBorder)),
                    child: Text(message.message,
                      style: TextStyle(color: isMine ? colors.primaryFg : colors.foreground, fontSize: 14, height: 1.35))));
              })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Container(padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(color: colors.glass, borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.glassBorder)),
            child: Row(children: [
              Expanded(child: TextField(controller: _controller, textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(), style: TextStyle(color: colors.foreground),
                decoration: InputDecoration(hintText: 'Message ${widget.friendName}...', hintStyle: TextStyle(color: colors.mutedFg), border: InputBorder.none))),
              IconButton(onPressed: _sending ? null : _send,
                icon: _sending ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                  : Icon(Icons.send_rounded, color: colors.primary)),
            ])))),
      ]),
    );
  }
}
