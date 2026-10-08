import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_service_provider.dart';

class AiStylistScreen extends ConsumerStatefulWidget {
  const AiStylistScreen({super.key});
  @override
  ConsumerState<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends ConsumerState<AiStylistScreen> {
  final _controller = TextEditingController();
  final _messages = <Map<String, String>>[];
  int? _conversationId;
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    try {
      final result = await ref.read(apiServiceProvider).aiStylistChat(
        message: text,
        conversationId: _conversationId,
      );
      _conversationId = (result['conversation_id'] as num?)?.toInt();
      setState(() => _messages.add({
        'role': 'assistant',
        'text': result['message']?.toString() ?? 'I could not generate a response.',
      }));
    } catch (e) {
      setState(() => _messages.add({
        'role': 'assistant',
        'text': 'I’m having trouble reaching the stylist right now. Please try again.',
      }));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Stylist')),
    body: Column(children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Ask for outfit ideas, styling advice, colours, occasions, or product suggestions.'),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final m = _messages[i];
          final user = m['role'] == 'user';
          return Align(
            alignment: user ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: user ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(m['text'] ?? ''),
            ),
          );
        },
      )),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(hintText: 'Ask your stylist…', border: OutlineInputBorder()),
          )),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _loading ? null : _send, icon: const Icon(Icons.send)),
        ]),
      )),
    ]),
  );
}
