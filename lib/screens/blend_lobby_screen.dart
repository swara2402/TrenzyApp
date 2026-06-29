import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/blend_model.dart';
import '../providers/auth_provider.dart';
import '../providers/blend_provider.dart';
import '../router/app_router.dart';
import '../services/blend_socket_service.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_utils.dart';

class BlendLobbyScreen extends ConsumerStatefulWidget {
  const BlendLobbyScreen({
    super.key,
    required this.onToggleTheme,
    required this.groupId,
  });

  final VoidCallback onToggleTheme;
  final String groupId;

  @override
  ConsumerState<BlendLobbyScreen> createState() => _BlendLobbyScreenState();
}

class _BlendLobbyScreenState extends ConsumerState<BlendLobbyScreen> {
  late final BlendSocketService _socket;
  BlendLiveState? _liveState;
  StreamSubscription<BlendLiveState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  String? _inviteToken;
  bool _isCreatingInvite = false;

  @override
  void initState() {
    super.initState();
    _socket = BlendSocketService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    _stateSub = _socket.stateStream.listen((state) {
      if (mounted) setState(() => _liveState = state);
    });
    _errorSub = _socket.errorStream.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    await _socket.joinBlend(
      groupId: widget.groupId,
      userId: user.id,
      userName: user.name.isNotEmpty ? user.name : 'You',
    );
  }

  Future<void> _createInvite() async {
    if (_isCreatingInvite) return;
    setState(() => _isCreatingInvite = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.createInvitation(groupId: widget.groupId);
      setState(() => _inviteToken = result['token']?.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite link created — share the code below'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingInvite = false);
    }
  }

  Future<void> _copyInviteCode() async {
    final code = _inviteToken ?? 'Generate an invite first';
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code copied to clipboard')),
      );
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _errorSub?.cancel();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(blendGroupProvider(widget.groupId));
    final List<BlendMember> members =
        _liveState?.members ??
        groupAsync.maybeWhen(
          data: (g) => g.members,
          orElse: () => const <BlendMember>[],
        ) ??
        const <BlendMember>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: groupAsync.when(
          loading: () => CustomScrollView(
            slivers: [
              AppTopBar(
                leading: Icons.arrow_back_rounded,
                trailing: Icons.refresh_rounded,
                onLeadingPressed: () => context.pop(),
                onTrailingPressed: () =>
                    ref.invalidate(blendGroupProvider(widget.groupId)),
                onToggleTheme: widget.onToggleTheme,
              ),
              const SliverFillRemaining(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _BlendLobbySkeleton(),
                ),
              ),
            ],
          ),
          error: (e, _) => CustomScrollView(
            slivers: [
              AppTopBar(
                leading: Icons.arrow_back_rounded,
                trailing: Icons.refresh_rounded,
                onLeadingPressed: () => context.pop(),
                onTrailingPressed: () =>
                    ref.invalidate(blendGroupProvider(widget.groupId)),
                onToggleTheme: widget.onToggleTheme,
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AsyncRetryErrorState(
                    title: 'Failed to load blend room',
                    message: friendlyErrorMessage(e),
                    onRetry: () =>
                        ref.invalidate(blendGroupProvider(widget.groupId)),
                  ),
                ),
              ),
            ],
          ),
          data: (group) {
            final swipeCounts = <String, int>{};
            if (_liveState != null) {
              for (final m in _liveState!.members) {
                swipeCounts[m.userId] = m.swipeCount;
              }
            }
            return CustomScrollView(
              slivers: [
                AppTopBar(
                  leading: Icons.arrow_back_rounded,
                  trailing: Icons.logout_rounded,
                  onLeadingPressed: () => context.pop(),
                  onTrailingPressed: _leaveBlend,
                  onToggleTheme: widget.onToggleTheme,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${members.length} member(s) · ${_liveState?.totalSwipes ?? 0} swipes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      _InviteCard(
                        inviteCode: _inviteToken ?? widget.groupId,
                        onGenerateInvite: _createInvite,
                        onCopy: _copyInviteCode,
                        isGenerating: _isCreatingInvite,
                        hasToken: _inviteToken != null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Members',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (members.isEmpty)
                        const Text('Waiting for friends to join...')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final member in members)
                              _MemberChip(
                                name: member.userName,
                                swipeCount: swipeCounts[member.userId] ?? 0,
                              ),
                          ],
                        ),
                      if (_liveState?.lastEvent != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _formatEvent(_liveState!.lastEvent!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () {
                          context.push(
                            AppRoutes.blendSwipe,
                            extra: widget.groupId,
                          );
                        },
                        icon: const Icon(Icons.swipe_rounded),
                        label: const Text('Start Swiping'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.push(
                            AppRoutes.blendChat,
                            extra: widget.groupId,
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Chat'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.push(
                            AppRoutes.blendResults,
                            extra: widget.groupId,
                          );
                        },
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: const Text('View Results'),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final name = event['userName']?.toString() ?? 'Someone';
    switch (type) {
      case 'member_joined':
        return '$name joined the blend';
      case 'member_left':
        return '$name left the blend';
      case 'swipe':
        return '$name swiped on a product';
      default:
        return 'Blend updated';
    }
  }

  Future<void> _leaveBlend() async {
    try {
      await ref.read(apiServiceProvider).leaveBlend(widget.groupId);
      if (mounted) context.pop();
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
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.inviteCode,
    required this.onGenerateInvite,
    required this.onCopy,
    required this.isGenerating,
    required this.hasToken,
  });

  final String inviteCode;
  final VoidCallback onGenerateInvite;
  final VoidCallback onCopy;
  final bool isGenerating;
  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasToken ? 'Invite link' : 'Invite friends',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (hasToken) ...[
            SelectableText(
              inviteCode,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy code'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Generate a link to invite friends to this blend.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isGenerating ? null : onGenerateInvite,
                icon: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(isGenerating ? 'Creating…' : 'Create invite link'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name, required this.swipeCount});

  final String name;
  final int swipeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name),
          if (swipeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$swipeCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlendLobbySkeleton extends StatelessWidget {
  const _BlendLobbySkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          LoadingSkeletonShimmer(height: 32, width: 220, radius: 6),
          const SizedBox(height: 8),
          LoadingSkeletonShimmer(height: 14, width: 120, radius: 4),
          const SizedBox(height: 24),
          LoadingSkeletonShimmer(height: 130, radius: 20),
          const SizedBox(height: 24),
          LoadingSkeletonShimmer(height: 20, width: 100, radius: 4),
          const SizedBox(height: 12),
          Row(
            children: [
              LoadingSkeletonShimmer(height: 32, width: 80, radius: 16),
              const SizedBox(width: 8),
              LoadingSkeletonShimmer(height: 32, width: 90, radius: 16),
              const SizedBox(width: 8),
              LoadingSkeletonShimmer(height: 32, width: 70, radius: 16),
            ],
          ),
          const SizedBox(height: 36),
          LoadingSkeletonShimmer(height: 48, radius: 12),
          const SizedBox(height: 12),
          LoadingSkeletonShimmer(height: 48, radius: 12),
          const SizedBox(height: 12),
          LoadingSkeletonShimmer(height: 48, radius: 12),
        ],
      ),
    );
  }
}
