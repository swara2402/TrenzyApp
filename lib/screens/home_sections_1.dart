part of 'home_screen.dart';

class _WelcomeHeader extends ConsumerWidget {
  const _WelcomeHeader();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final rawName = authAsync.valueOrNull?.name;
    final userName = (rawName == null || rawName.trim().isEmpty)
        ? 'Fashionista'
        : rawName;
    final personaAsync = ref.watch(personaProvider);
    final personaName = personaAsync.valueOrNull?.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TRENZY',
                style: TextStyle(
                  fontFamily: GlassTypography.bodyFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                  color: context.trenzyColors.primary,
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 4),
          DisplayText('${_greeting()}, $userName!', fontSize: 26),
          if (personaName != null) ...[
            SizedBox(height: 2),
            Text(
              personaName,
              style: TextStyle(
                fontFamily: GlassTypography.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.trenzyColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiPersonaCard extends ConsumerWidget {
  const _AiPersonaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personaAsync = ref.watch(personaProvider);
    final personaName = personaAsync.valueOrNull?.name ?? 'Style Newcomer';
    return GlassContainer(
      color: context.trenzyColors.graphite,
      radius: 16,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go(AppRoutes.persona),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: GlassGradients.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: context.trenzyColors.primary.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: context.trenzyColors.primaryFg,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your AI Persona',
                        style: TextStyle(
                          fontFamily: GlassTypography.bodyFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: context.trenzyColors.primary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        personaName,
                        style: TextStyle(
                          fontFamily: GlassTypography.bodyFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.trenzyColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.trenzyColors.mutedFg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}