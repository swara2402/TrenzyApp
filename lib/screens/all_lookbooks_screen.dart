import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/models/wardrobe_model.dart';
import 'package:trenzy/theme/glass_theme.dart';

class AllLookbooksScreen extends ConsumerWidget {
  const AllLookbooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfitsAsync = ref.watch(outfitsProvider);

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.trenzyColors.foreground),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Lookbooks',
          style: TextStyle(
            color: context.trenzyColors.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.trenzyColors.mutedFg),
            onPressed: () => ref.invalidate(outfitsProvider),
          ),
        ],
      ),
      body: outfitsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.trenzyColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, color: context.trenzyColors.mutedFg, size: 48),
              SizedBox(height: 16),
              Text(
                'Could not load lookbooks',
                style: GlassTypography.body(color: context.trenzyColors.mutedFg),
              ),
              SizedBox(height: 12),
              GlowButton(
                label: 'Retry',
                width: 100,
                height: 36,
                onTap: () => ref.invalidate(outfitsProvider),
              ),
            ],
          ),
        ),
        data: (outfits) {
          if (outfits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.trenzyColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.style_outlined, size: 36, color: context.trenzyColors.primary),
                  ),
                  SizedBox(height: 20),
                  DisplayText('No lookbooks yet', fontSize: 18, weight: FontWeight.w600),
                  SizedBox(height: 8),
                  Text(
                    'Create outfits in your wardrobe to build lookbooks.',
                    style: GlassTypography.body(color: context.trenzyColors.mutedFg, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  GlowButton(
                    label: 'Go to Wardrobe',
                    width: 180,
                    height: 44,
                    onTap: () => context.push(AppRoutes.wardrobe),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(outfitsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: outfits.length,
              itemBuilder: (context, index) {
                final outfit = outfits[index];
                return _LookbookCard(outfit: outfit);
              },
            ),
          );
        },
      ),
    );
  }
}

class _LookbookCard extends StatelessWidget {
  final Outfit outfit;

  const _LookbookCard({required this.outfit});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      color: context.trenzyColors.graphite,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image grid (top section)
          Expanded(
            flex: 3,
            child: outfit.items.isNotEmpty
                ? _buildImageGrid(outfit.items)
                : Container(
                    decoration: BoxDecoration(
                      color: context.trenzyColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Icon(
                      Icons.style_outlined,
                      color: context.trenzyColors.mutedFg,
                      size: 32,
                    ),
                  ),
          ),
          // Outfit info (bottom section)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name,
                    style: TextStyle(
                      color: context.trenzyColors.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${outfit.items.length} items',
                    style: TextStyle(
                      color: context.trenzyColors.mutedFg,
                      fontSize: 11,
                    ),
                  ),
                  Spacer(),
                  if (outfit.occasion != null && outfit.occasion!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.trenzyColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        outfit.occasion!,
                        style: TextStyle(
                          color: context.trenzyColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<WardrobeItem> items) {
    final displayItems = items.take(4).toList();

    if (displayItems.length == 1) {
      return _buildSingleImage(displayItems[0]);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        physics: NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        children: displayItems.map((item) {
          return item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.trenzyColors.background,
                    child: Icon(Icons.checkroom_rounded, color: context.trenzyColors.mutedFg, size: 16),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: GlassColors.background,
                    child: Icon(Icons.broken_image, color: GlassColors.mutedFg, size: 16),
                  ),
                )
              : Container(
                  color: GlassColors.background,
                  child: Icon(Icons.checkroom_rounded, color: GlassColors.mutedFg, size: 16),
                );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleImage(WardrobeItem item) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: GlassColors.background,
                child: Icon(Icons.checkroom_rounded, color: GlassColors.mutedFg, size: 24),
              ),
              errorWidget: (context, url, error) => Container(
                color: GlassColors.background,
                child: Icon(Icons.broken_image, color: GlassColors.mutedFg, size: 24),
              ),
            )
          : Container(
              color: GlassColors.background,
              child: Icon(Icons.checkroom_rounded, color: GlassColors.mutedFg, size: 24),
            ),
    );
  }
}