part of 'home_screen.dart';

class _SeeMoreSection extends ConsumerWidget {
  const _SeeMoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.discover),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: context.trenzyColors.graphite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.trenzyColors.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_rounded,
                  size: 18, color: context.trenzyColors.primary),
              SizedBox(width: 6),
              Text(
                'See more styles',
                style: TextStyle(
                  fontFamily: GlassTypography.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.trenzyColors.primary,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.trenzyColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
