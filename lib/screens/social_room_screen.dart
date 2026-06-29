import 'dart:async';
import '../models/social_room_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/decision_flow.dart';
import '../models/product_model.dart';
import '../router/app_router.dart';
import '../services/socket_service.dart';
import '../widgets/app_widgets.dart';

class SocialRoomScreen extends StatefulWidget {
  const SocialRoomScreen({
    super.key,
    required this.onToggleTheme,
    required this.query,
    required this.selectedOptions,
    required this.roomId,
  });

  final VoidCallback onToggleTheme;
  final String query;
  final List<SuggestionOption> selectedOptions;
  final String roomId;

  @override
  State<SocialRoomScreen> createState() => _SocialRoomScreenState();
}

class _SocialRoomScreenState extends State<SocialRoomScreen> {
  late final SocketService _socketService;
  late SocialRoomState _roomState;
  late final String _userId;
  late final String _userName;

  StreamSubscription<SocialRoomState>? _roomSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _roomState = SocialRoomState.empty(
      widget.selectedOptions.map((o) => o.product).toList(),
    );
    final user = FirebaseAuth.instance.currentUser;
    _userId = user?.uid ?? 'guest-${DateTime.now().millisecondsSinceEpoch}';
    _userName = user?.displayName ?? user?.email?.split('@').first ?? 'You';
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    _roomSubscription = _socketService.roomStateStream.listen((roomState) {
      if (!mounted) return;
      setState(() {
        _roomState = roomState;
      });
    });

    _errorSubscription = _socketService.errorStream.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    await _socketService.joinRoom(
      roomId: widget.roomId,
      userId: _userId,
      userName: _userName,
      options: widget.selectedOptions.map((o) => o.product).toList(),
    );
  }

  void _submitVote(ProductModel option) {
    _socketService.sendVote(
      roomId: widget.roomId,
      optionId: option.id,
      userId: _userId,
      userName: _userName,
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _errorSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reactions = _roomState.reactions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            AppTopBar(
              leading: Icons.arrow_back_rounded,
              trailing: Icons.groups_rounded,
              onLeadingPressed: () => context.pop(),
              onToggleTheme: widget.onToggleTheme,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Social Room',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Friends are reacting to "${widget.query}" in room ${widget.roomId}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildParticipantsRow(),
                  const SizedBox(height: 18),
                  _InviteLinkCard(roomId: widget.roomId),
                  const SizedBox(height: 18),
                  // ✅ Updated to use ProductModel
                  for (final option in widget.selectedOptions) ...[
                    _SocialVoteCard(
                      option: option.product,
                      votes: _roomState.voteCounts[option.id] ?? 0,
                      isVoted: _roomState.lastVotedOptionId == option.id,
                      onVote: () => _submitVote(option.product),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ReactionChip(icon: '\u{1F525}'),
                      ReactionChip(icon: '\u{1F496}'),
                      ReactionChip(icon: '\u{2728}'),
                      ReactionChip(icon: '\u{2B50}'),
                      ReactionChip(icon: '\u{1F929}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Live Activity'),
                  const SizedBox(height: 12),
                  if (reactions.isEmpty)
                    const FriendlyEmptyState(
                      title: 'The room is warming up',
                      message:
                          'Votes will appear here as soon as someone reacts.',
                      icon: Icons.groups_rounded,
                    )
                  else
                    for (final reaction in reactions)
                      ActivityTile(
                        name:
                            '${reaction.friendName} reacted ${reaction.emoji}',
                        subtitle: reaction.note,
                        dotColor: const Color(0xFFF6A2CC),
                      ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Room Chat'),
                  const SizedBox(height: 12),
                  if (reactions.isEmpty)
                    const FriendlyEmptyState(
                      title: 'No messages yet',
                      message:
                          'Ask the room to vote and the chat feed will update in real time.',
                      icon: Icons.chat_bubble_outline_rounded,
                    )
                  else
                    for (final reaction in reactions)
                      ChatBubble(
                        message: '${reaction.friendName}: ${reaction.note}',
                        highlight:
                            reaction.optionId == _roomState.lastVotedOptionId,
                      ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: TapScale(
                      child: FilledButton(
                        onPressed: () {
                          context.push(
                            AppRoutes.decision,
                            extra: DecisionRouteExtra(
                              query: widget.query,
                              selectedOptions: widget.selectedOptions,
                              reactions: reactions,
                            ),
                          );
                        },
                        child: const Text('Finalize Decision'),
                      ),
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

  Widget _buildParticipantsRow() {
    final participantCount = _roomState.participantCount;
    final visibleCount = participantCount > 4 ? 4 : participantCount;

    return Row(
      children: List.generate(
        visibleCount,
        (index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: CircleAvatar(
            radius: 12,
            backgroundColor: [
              const Color(0xFFEDC5D7),
              const Color(0xFFC9B6F5),
              const Color(0xFFF7D8AA),
              const Color(0xFFDCB8FF),
            ][index],
            child: index == visibleCount - 1 && participantCount > 4
                ? Text(
                    '+${participantCount - 3}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// ✅ NEW: Social Vote Card using ProductModel
class _SocialVoteCard extends StatelessWidget {
  const _SocialVoteCard({
    required this.option,
    required this.votes,
    required this.isVoted,
    required this.onVote,
  });

  final ProductModel option;
  final int votes;
  final bool isVoted;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVoted
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isVoted
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withValues(alpha: 0.12),
          width: isVoted ? 1.5 : 1,
        ),
        boxShadow: isVoted
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 70,
              height: 70,
              child: option.imageUrl != null && option.imageUrl!.isNotEmpty
                  ? Image.network(
                      option.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.shopping_bag_rounded),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.shopping_bag_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (option.brand != null && option.brand!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(option.brand!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      option.formattedPrice,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$votes votes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Vote button
          IconButton(
            onPressed: onVote,
            icon: Icon(
              isVoted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isVoted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inviteText = 'Room code: $roomId';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : const Color(0xFFF7F1FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE6D7F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite friends to this blend',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            inviteText,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TapScale(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: roomId));
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Room code copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy room code'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
