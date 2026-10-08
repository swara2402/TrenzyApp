import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_service_provider.dart';

class AiStyleDnaScreen extends ConsumerStatefulWidget {
  const AiStyleDnaScreen({super.key});
  @override ConsumerState<AiStyleDnaScreen> createState() => _AiStyleDnaScreenState();
}

class _AiStyleDnaScreenState extends ConsumerState<AiStyleDnaScreen> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = ref.read(apiServiceProvider).getStyleDna(); }
  Future<void> _refresh() async {
    await ref.read(apiServiceProvider).refreshStyleDna();
    if (mounted) setState(() => _future = ref.read(apiServiceProvider).getStyleDna());
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your Style DNA'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: FilledButton(onPressed: () => setState(() => _future = ref.read(apiServiceProvider).getStyleDna()), child: const Text('Retry')));
        final data = snapshot.data ?? <String, dynamic>{};
        final sections = <String, dynamic>{'Styles': data['style_scores'], 'Colours': data['color_scores'], 'Fits': data['fit_scores'], 'Brands': data['brand_scores'], 'Categories': data['category_scores'], 'Occasions': data['occasion_scores']};
        final confidence = (double.tryParse('${data['confidence'] ?? 0}') ?? 0).clamp(0, 1);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(data['explanation']?.toString() ?? 'Your style profile is learning from your interactions.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text('Confidence ${(confidence * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            for (final entry in sections.entries) if (entry.value is Map && (entry.value as Map).isNotEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.key, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10),
                for (final item in (entry.value as Map).entries.take(6)) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                  Expanded(child: Text(item.key.toString())),
                  SizedBox(width: 110, child: LinearProgressIndicator(value: (double.tryParse(item.value.toString()) ?? 0).clamp(0, 1))),
                ])),
              ]))),
            const SizedBox(height: 12), Text('Interactions learned: ${data['interaction_count'] ?? 0}'),
          ]),
        );
      },
    ),
  );
}