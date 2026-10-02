import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenzy/models/blend_model.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/blend_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/analytics/events.dart';

class JoinBlendScreen extends ConsumerStatefulWidget {
  const JoinBlendScreen({super.key});

  @override
  ConsumerState<JoinBlendScreen> createState() => _JoinBlendScreenState();
}

class _JoinBlendScreenState extends ConsumerState<JoinBlendScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyboardFocusNodes =
      List.generate(6, (_) => FocusNode());
  bool _isJoining = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _inviteCode => _controllers.map((c) => c.text).join();

  String _formatJoinError(dynamic error) {
    final text = error.toString().toLowerCase();
    if (text.contains('full')) return 'This Blend session is full.';
    if (text.contains('invalid') || text.contains('not found') || text.contains('404')) {
      return 'Invalid invite code. Check and try again.';
    }
    if (text.contains('private')) return 'This Blend session is private and requires an invite.';
    if (text.contains('rate') || text.contains('limit') || text.contains('429')) {
      return 'Too many join attempts. Please try again in a moment.';
    }
    return 'Could not join blend. Please check your code and try again.';
  }

  Future<void> _joinWithCode() async {
    final code = _inviteCode.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid invite code')),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final api = ref.read(apiServiceProvider);
      // The code may be an invite code, so the payload's real blend `id` is
      // what we navigate to (lobby / GET endpoints key off the id).
      final res = await api.joinBlend(groupId: code);
      trackBlendJoined(ref, code);
      final blendId = res['id']?.toString();
      if (mounted) {
        context.go('${AppRoutes.blendLobby}?groupId=${(blendId != null && blendId.isNotEmpty) ? blendId : code}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatJoinError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _joinGroup(String groupId) async {
    if (groupId.isEmpty) return;
    setState(() => _isJoining = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.joinBlend(groupId: groupId);
      trackBlendJoined(ref, groupId);
      if (mounted) {
        context.go('${AppRoutes.blendLobby}?groupId=$groupId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatJoinError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blendsAsync = ref.watch(userBlendGroupsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF16130B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16130B).withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFEAE1D4)),
          onPressed: () => context.go(AppRoutes.blendHub),
        ),
        title: const Text(
          'Trenzy',
          style: TextStyle(
            color: Color(0xFFF2CA50),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildHeader(),
            const SizedBox(height: 48),
            _buildCodeInput(context),
            const SizedBox(height: 48),
            _buildPendingInvites(blendsAsync),
          ],
        ),
      ),
      floatingActionButton: _buildJoinButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Join Blend',
          style: TextStyle(
            color: Color(0xFFEAE1D4),
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the secret code to sync your aesthetic with the collective.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFD0C5AF),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInput(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildCodeBox(index)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: const Color(0xFF4D4635).withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'OR',
                style: TextStyle(
                  color: const Color(0xFF99907C),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: const Color(0xFF4D4635).withValues(alpha: 0.3))),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 48,
      height: 64,
      child: KeyboardListener(
        focusNode: _keyboardFocusNodes[index],
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            color: Color(0xFFEAE1D4),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1F1B13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF2CA50), width: 1.5),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }
            if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            if (_inviteCode.length == 6) {
              _joinWithCode();
            }
          },
        ),
      ),
    );
  }

  Widget _buildPendingInvites(AsyncValue<List<dynamic>> blendsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR BLEND GROUPS'.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFD0C5AF),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        blendsAsync.when(
          data: (groups) {
            if (groups.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No pending invites yet.\nShare your blend code with friends!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF99907C), fontSize: 14),
                ),
              );
            }
            return Column(
              children: groups
                  .where((g) => g is Map || g is BlendGroup)
                  .map((g) {
                final map = g is BlendGroup
                    ? {'id': g.id, 'name': g.name, 'memberCount': g.memberCount}
                    : Map<String, dynamic>.from(g as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildInviteCard(
                    name: map['name']?.toString() ?? 'Blend',
                    match: '${map['memberCount'] ?? 0} members',
                    onTap: () => _joinGroup(map['id']?.toString() ?? ''),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFF2CA50))),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Could not load invites',
              style: TextStyle(color: const Color(0xFF99907C)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCard({
    required String name,
    required String match,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF231F17).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF2D2A21),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFF2CA50),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFEAE1D4),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    match.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF6BFE9C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF99907C)),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        onPressed: _isJoining ? null : _joinWithCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2CA50),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        child: _isJoining
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3C2F00),
                ),
              )
            : Text(
                'JOIN SESSION'.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF3C2F00),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
