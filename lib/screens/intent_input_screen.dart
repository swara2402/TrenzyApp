import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/glass_theme.dart';

/// AI intent input screen — lets the user describe what they're looking for
/// in natural language (e.g. "something for a beach wedding") and navigates
/// to the search or swipe-discovery experience with that intent.
class IntentInputScreen extends StatefulWidget {
  const IntentInputScreen({super.key});

  @override
  State<IntentInputScreen> createState() => _IntentInputScreenState();
}

class _IntentInputScreenState extends State<IntentInputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _prompts = [
    'Something for a beach wedding…',
    'Cozy weekend errands fit…',
    'Date night, smart casual…',
    'Office look, quiet luxury…',
    'Festival season vibes…',
    'Gym to brunch, athleisure…',
  ];

  final int _promptIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    context.push('${AppRoutes.search}?q=${Uri.encodeComponent(query)}');
  }

  void _usePrompt(String prompt) {
    _controller.text = prompt;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.trenzyColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GlassBackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you\nlooking for?',
                style: GlassTypography.display(
                  fontSize: 30,
                  color: c.foreground,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Describe the vibe, occasion or item.',
                style: GlassTypography.body(
                  fontSize: 14,
                  color: c.mutedFg,
                ),
              ),
              const SizedBox(height: 28),

              // Intent text field
              Container(
                decoration: BoxDecoration(
                  color: c.graphite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.glassBorder),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  style: GlassTypography.body(
                    fontSize: 16,
                    color: c.foreground,
                  ),
                  decoration: InputDecoration(
                    hintText: _prompts[_promptIndex % _prompts.length],
                    hintStyle: GlassTypography.body(
                      fontSize: 16,
                      color: c.mutedFg,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: c.primary,
                      ),
                      onPressed: _submit,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'TRY ONE OF THESE',
                style: TextStyle(
                  fontFamily: GlassTypography.bodyFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _prompts.map((prompt) {
                  return GestureDetector(
                    onTap: () => _usePrompt(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.graphite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: Text(
                        prompt,
                        style: GlassTypography.body(
                          fontSize: 13,
                          color: c.foreground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: GlowButton(
                  label: 'Search',
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}