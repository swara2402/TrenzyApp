import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/friend_provider.dart';
import '../providers/api_service_provider.dart';
import '../router/app_router.dart';
import '../theme/glass_theme.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _uidController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = const [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _uidController.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (query.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchError = 'Enter at least 2 characters from their username.';
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = const [];
    });
    try {
      final results = await ref.read(apiServiceProvider).searchUsersByUsername(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchError = results.isEmpty ? 'No users found. Check the username and try again.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Could not search right now. Please try again.';
        _searchResults = const [];
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendTo(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      await ref.read(friendsProvider.notifier).sendRequest(uid);
      if (mounted) {
        setState(() {
          _searchResults = _searchResults.where((u) => u['firebaseUid'] != uid).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent 💛')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(friendsProvider);
    final colors = context.trenzyColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.foreground),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Friends',
          style: TextStyle(
            color: colors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.mutedFg,
          tabs: [
            Tab(
              text: async.valueOrNull == null
                  ? 'Friends'
                  : 'Friends (${async.valueOrNull!.friendCount})',
            ),
            Tab(
              text: async.valueOrNull == null
                  ? 'Requests'
                  : 'Requests (${async.valueOrNull!.pendingCount})',
            ),
            const Tab(text: 'Find'),
          ],
        ),
      ),
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: colors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load friends',
                style: TextStyle(color: colors.mutedFg),
              ),
              TextButton(
                onPressed: () => ref.read(friendsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) => TabBarView(
          controller: _tabs,
          children: [
            _FriendsList(state: state),
            _RequestsList(state: state),
            _FindList(state: state, controller: _uidController, results: _searchResults, isSearching: _isSearching, searchError: _searchError, onSearch: _searchUsers, onSend: _sendTo),
          ],
        ),
      ),
    );
  }
}

class _FriendsList extends ConsumerWidget {
  const _FriendsList({required this.state});
  final FriendsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    if (state.friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No friends yet. Open Find to send a request.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedFg),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.friends.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final f = state.friends[i];
        return ListTile(
          tileColor: colors.graphite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.2),
            child: Text(
              f.name != null && f.name!.isNotEmpty
                  ? f.name![0].toUpperCase()
                  : '?',
              style: TextStyle(color: colors.primary),
            ),
          ),
          title: Text(f.name ?? '', style: TextStyle(color: colors.foreground)),
          subtitle: Text(
            f.user?.username != null && f.user!.username.isNotEmpty ? '@${f.user!.username}' : 'Trenzy friend',
            style: TextStyle(color: colors.mutedFg, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Message',
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: colors.primary,
                ),
                onPressed: () => context.push(
                  '/chat/direct?uid=${Uri.encodeComponent(f.firebaseUid ?? '')}&name=${Uri.encodeComponent(f.name ?? '')}',
                ),
              ),
              IconButton(
                tooltip: 'Report user',
                icon: Icon(Icons.flag_outlined, color: colors.mutedFg),
                onPressed: () => _showReportDialog(
                  context,
                  ref,
                  f.firebaseUid ?? '',
                  f.name ?? '',
                ),
              ),
              IconButton(
                tooltip: 'Remove friend',
                icon: Icon(Icons.person_remove_outlined, color: colors.crimson),
                onPressed: () => ref
                    .read(friendsProvider.notifier)
                    .remove(int.tryParse(f.id ?? '') ?? 0),
              ),
            ],
          ),
          onTap: () => context.push(
            '${AppRoutes.userProfile}?uid=${Uri.encodeComponent(f.firebaseUid ?? '')}',
          ),
        );
      },
    );
  }
}

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.state});
  final FriendsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    if (state.incoming.isEmpty) {
      return Center(
        child: Text(
          'No pending requests',
          style: TextStyle(color: colors.mutedFg),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.incoming.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = state.incoming[i];
        return ListTile(
          tileColor: colors.graphite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            r.fromName ?? '',
            style: TextStyle(color: colors.foreground),
          ),
          subtitle: Text(
            r.fromUser?.username != null && r.fromUser!.username.isNotEmpty ? '@${r.fromUser!.username}' : 'Friend request',
            style: TextStyle(color: colors.mutedFg, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check, color: colors.emerald),
                onPressed: () => ref
                    .read(friendsProvider.notifier)
                    .accept(int.tryParse(r.id ?? '') ?? 0),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.crimson),
                onPressed: () => ref
                    .read(friendsProvider.notifier)
                    .reject(int.tryParse(r.id ?? '') ?? 0),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FindList extends ConsumerWidget {
  const _FindList({
    required this.state,
    required this.controller,
    required this.results,
    required this.isSearching,
    required this.searchError,
    required this.onSearch,
    required this.onSend,
  });

  final FriendsState state;
  final TextEditingController controller;
  final List<Map<String, dynamic>> results;
  final bool isSearching;
  final String? searchError;
  final VoidCallback onSearch;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.trenzyColors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: controller,
          style: TextStyle(color: colors.foreground),
          decoration: InputDecoration(
            hintText: 'Find by username (e.g. @yourname)',
            hintStyle: TextStyle(color: colors.mutedFg),
            suffixIcon: IconButton(
              icon: Icon(Icons.send, color: colors.primary),
              onPressed: onSearch,
            ),
            filled: true,
            fillColor: colors.graphite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => onSearch(),
        ),
        const SizedBox(height: 12),
        if (isSearching)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(color: colors.primary),
          )),
        if (searchError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(searchError!, style: TextStyle(color: colors.mutedFg)),
          ),
        ...results.map((user) {
          final uid = user['firebaseUid']?.toString() ?? '';
          final username = user['username']?.toString() ?? '';
          final name = user['name']?.toString() ?? 'Trenzy user';
          final avatar = user['avatarUrl']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              tileColor: colors.graphite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: .16),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: colors.primary)) : null,
              ),
              title: Text(name, style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w700)),
              subtitle: Text('@$username', style: TextStyle(color: colors.mutedFg)),
              trailing: FilledButton(
                onPressed: uid.isEmpty ? null : () => onSend(uid),
                style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.background),
                child: const Text('Add'),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Suggested',
          style: TextStyle(
            color: colors.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        if (state.suggestions.isEmpty)
          Text('No suggestions yet', style: TextStyle(color: colors.mutedFg))
        else
          ...state.suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: colors.graphite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  s.name ?? '',
                  style: TextStyle(color: colors.foreground),
                ),
                subtitle: Text(
                  s.reason?.replaceAll('_', ' ') ?? '',
                  style: TextStyle(color: colors.mutedFg, fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(friendsProvider.notifier)
                      .sendRequest(s.firebaseUid ?? ''),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  String targetUid,
  String targetName,
) async {
  const reasons = <String, String>{
    'spam': 'Spam',
    'harassment': 'Harassment',
    'hate': 'Hate or abusive content',
    'sexual': 'Sexual content',
    'violence': 'Violence or threats',
    'other': 'Other',
  };
  String selected = 'other';
  final detailsController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Report $targetName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              items: reasons.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selected = value ?? 'other'),
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    ),
  );

  if (submitted != true || !context.mounted) {
    detailsController.dispose();
    return;
  }

  try {
    await ref
        .read(apiServiceProvider)
        .reportUser(
          targetFirebaseUid: targetUid,
          reason: selected,
          details: detailsController.text,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit report: $e')));
    }
  } finally {
    detailsController.dispose();
  }
}
