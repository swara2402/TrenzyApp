part of 'home_screen.dart';

class _ContinueBlendSlot extends ConsumerWidget {
  const _ContinueBlendSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userBlendGroupsProvider);

    return groupsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: ErrorSection(
          title: 'Couldn\u2019t load your blend',
          message: 'Your active Blend is unavailable right now.',
          compact: true,
          padding: EdgeInsets.zero,
          onRetry: () => ref.invalidate(userBlendGroupsProvider),
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        final group = groups.first;
        return Column(
          children: [
            SizedBox(height: 24),
            StaggeredEntry(index: 5, child: _ContinueBlendCard(group: group)),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _ContinueBlendCard extends StatelessWidget {
  const _ContinueBlendCard({required this.group});

  final BlendGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.blendHub),
        child: Container(
          decoration: BoxDecoration(
            color: context.trenzyColors.graphite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 5,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.trenzyColors.primary, context.trenzyColors.emerald],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.trenzyColors.emerald,
                              boxShadow: [
                                BoxShadow(
                                  color: context.trenzyColors.emerald.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              group.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.trenzyColors.foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people_rounded,
                              size: 14, color: context.trenzyColors.mutedFg),
                          SizedBox(width: 4),
                          Text(
                            '${group.memberCount} ${group.memberCount == 1 ? 'person' : 'people'} swiping',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.trenzyColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: GlassGradients.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: context.trenzyColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Continue \u2192',
                    style: TextStyle(
                      color: context.trenzyColors.primaryFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

