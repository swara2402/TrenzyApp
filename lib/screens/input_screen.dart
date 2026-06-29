import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/decision_flow.dart';
import '../router/app_router.dart';
import '../widgets/app_widgets.dart';

class IntentInputScreen extends StatefulWidget {
  const IntentInputScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<IntentInputScreen> createState() => _IntentInputScreenState();
}

class _IntentInputScreenState extends State<IntentInputScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }

    context.push(
      AppRoutes.suggestions,
      extra: SuggestionsRouteExtra(query: query),
    );
  }

  void _applyPrompt(String value) {
    setState(() {
      _controller.text = value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.edit_note_rounded,
              onLeadingPressed: () => context.pop(),
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Tell Trenzy what you are deciding.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your vibe, occasion, or style question. We will pass it straight into AI suggestions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: (bodyColor ?? Colors.grey).withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SearchField(
                    controller: _controller,
                    autoFocus: true,
                    hintText: 'Example: outfit for a rooftop dinner in Mumbai',
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InputChip(
                        label: 'Brunch outfit with pastel tones',
                        onTap: () =>
                            _applyPrompt('Brunch outfit with pastel tones'),
                      ),
                      _InputChip(
                        label: 'Date night look with gold accents',
                        onTap: () =>
                            _applyPrompt('Date night look with gold accents'),
                      ),
                      _InputChip(
                        label: 'Casual airport fit',
                        onTap: () => _applyPrompt('Casual airport fit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _controller.text.trim().isEmpty
                          ? null
                          : _submit,
                      child: const Text('See Suggestions'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputChip extends StatelessWidget {
  const _InputChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: MoodChip(
        label: label,
        tint: isDark ? const Color(0xFF2A2239) : const Color(0xFFF4E6F7),
      ),
    );
  }
}
