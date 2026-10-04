import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenzy/providers/products_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/theme/glass_theme.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedCategory;

  // Map root category names to representative icons
  static const Map<String, IconData> _rootCategoryIcons = {
    'Upper': Icons.checkroom_outlined,
    'Bottom': Icons.man_outlined,
    'Footwear': Icons.hiking_outlined,
    'tops': Icons.checkroom_outlined,
    'bottoms': Icons.man_outlined,
    'footwear': Icons.hiking_outlined,
    'accessories': Icons.watch_outlined,
  };

  // Colors for category tiles
  static const List<Color> _tileColors = [
    Color(0xFF2A2520),
    Color(0xFF1E2A1F),
    Color(0xFF1F2230),
  ];

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(GlassSpacing.lg, 8, GlassSpacing.lg, 0),
              child: Row(
                children: [
                  GlassBackButton(onTap: () => context.pop()),
                  SizedBox(width: 8),
                  DisplayText('Categories', fontSize: 24, weight: FontWeight.w600, color: context.trenzyColors.primary),
                ],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
              child: Text(
                'Explore fashion by category',
                style: GlassTypography.body(color: context.trenzyColors.mutedFg.withValues(alpha: 0.7)),
              ),
            ),
            SizedBox(height: 20),

            // ── Category grid ───────────────────────────────────────
            Expanded(
              child: categoriesAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.trenzyColors.primary, strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: context.trenzyColors.mutedFg.withValues(alpha: 0.4)),
                      SizedBox(height: 16),
                      Text(
                        'Could not load categories',
                        style: GlassTypography.body(color: context.trenzyColors.mutedFg),
                      ),
                      SizedBox(height: 12),
                      GlowButton(
                        label: 'Retry',
                        width: 120,
                        height: 40,
                        onTap: () => ref.invalidate(categoriesProvider),
                      ),
                    ],
                  ),
                ),
                data: (categories) {
                  if (categories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_outlined, size: 64, color: context.trenzyColors.mutedFg.withValues(alpha: 0.3)),
                          SizedBox(height: 16),
                          DisplayText('No categories yet', fontSize: 18, weight: FontWeight.w600),
                          SizedBox(height: 8),
                          Text(
                            'Categories will appear once products are loaded.',
                            style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Root categories grid
                      Expanded(
                        flex: _selectedCategory != null ? 1 : 1,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.lg),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final icon = _rootCategoryIcons[cat] ?? Icons.category_outlined;
                            final color = _tileColors[index % _tileColors.length];
                            final isSelected = _selectedCategory == cat;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = isSelected ? null : cat;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? context.trenzyColors.primary : context.trenzyColors.glassBorder,
                                    width: isSelected ? 2 : 0.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: context.trenzyColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, size: 24, color: context.trenzyColors.primary),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        color: context.trenzyColors.foreground,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Subcategories list if a category is selected
                      if (_selectedCategory != null)
                        Expanded(
                          flex: 2,
                          child: _buildSubcategoriesList(ref, _selectedCategory!),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoriesList(WidgetRef ref, String categoryName) {
    final subcategoriesAsync = ref.watch(subcategoriesProvider(categoryName));
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: GlassSpacing.lg, right: GlassSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subcategories for $categoryName',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          SizedBox(height: 16),
          Expanded(
            child: subcategoriesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: context.trenzyColors.primary)),
              error: (err, _) => Center(
                child: Text('Failed to load subcategories', style: TextStyle(color: context.trenzyColors.mutedFg)),
              ),
              data: (subcategories) {
                return ListView.builder(
                  itemCount: subcategories.length,
                  itemBuilder: (context, index) {
                    final subcat = subcategories[index];
                    return ListTile(
                      title: Text(subcat, style: TextStyle(color: Colors.white)),
                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                      onTap: () {
                        context.push(
                          '${AppRoutes.search}?category=${Uri.encodeComponent(categoryName)}&subcategory=${Uri.encodeComponent(subcat)}',
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}