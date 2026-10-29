part of 'home_screen.dart';

class _WelcomeHeader extends ConsumerStatefulWidget {
  const _WelcomeHeader();

  @override
  ConsumerState<_WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends ConsumerState<_WelcomeHeader> {
  Timer? _clockRefresh;

  @override
  void initState() {
    super.initState();
    // DateTime.now() is not reactive; refresh so the greeting changes while
    // the Home screen stays open across morning/afternoon/evening.
    _clockRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockRefresh?.cancel();
    super.dispose();
  }

  String _greeting() {
    final now = DateTime.now();
    final hour = now.hour;
    // Keep the greeting playful and flirty without sounding identical every
    // time the user opens Home. Rotate by date/hour for stable, local copy.
    const morning = [
      'Hey, sunshine ☀️',
      'Morning, pretty thing ✨',
      'Hey, sweetie 💋',
      'Rise and slay, babe 💅',
      'Well hello, cutie 🫶',
    ];
    const afternoon = [
      'Hey, hottie 💋',
      'Looking cute today? 😏',
      'Hey, pretty thing ✨',
      'What’s the vibe, babe? 💅',
      'Hi, sweetie 🫶',
    ];
    const evening = [
      'Hey, gorgeous 🌙',
      'Well hello, heartbreaker 💋',
      'Evening, hottie 😏',
      'Hey, pretty thing ✨',
      'Ready to serve a look, babe? 💅',
    ];
    final options = hour < 12 ? morning : hour < 17 ? afternoon : evening;
    final index = (now.day + hour) % options.length;
    return options[index];
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
    final prefs = ref.watch(userPreferencesProvider);
    final personaName = personaAsync.valueOrNull?.name;
    final chosenStyles = [
      ...prefs.preferredStyles,
      ...prefs.preferredAesthetics,
    ].toSet().toList();
    final summary = chosenStyles.isNotEmpty
        ? chosenStyles.take(3).join(' · ')
        : (prefs.preferredCategories.isNotEmpty
            ? prefs.preferredCategories.take(3).join(' · ')
            : 'Choose the styles that feel like you');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassContainer(
        color: context.trenzyColors.graphite,
        radius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push(AppRoutes.stylePreferences),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.trenzyColors.primary.withValues(alpha: 0.28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.trenzyColors.primary.withValues(alpha: 0.10),
                    context.trenzyColors.graphite,
                    context.trenzyColors.graphite,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: GlassGradients.primary,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: context.trenzyColors.primary.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: context.trenzyColors.primaryFg,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR STYLE PERSONA',
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: context.trenzyColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          personaName?.isNotEmpty == true
                              ? personaName!
                              : 'Make your style yours',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: GlassTypography.bodyFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.trenzyColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: context.trenzyColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          color: context.trenzyColors.primary, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        'EDIT',
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
