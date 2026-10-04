import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/blend_model.dart';
import '../providers/blend_dashboard_provider.dart';
import '../theme/glass_theme.dart';

class MoodboardScreen extends ConsumerStatefulWidget {
  const MoodboardScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  ConsumerState<MoodboardScreen> createState() => _MoodboardScreenState();
}

class _MoodboardScreenState extends ConsumerState<MoodboardScreen> {
  String? _itemTypeFilter;

  @override
  Widget build(BuildContext context) {
    if (widget.groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: FriendlyEmptyState(
            title: 'No blend selected',
            message: 'Join or create a blend to see moodboard',
            icon: Icons.palette_outlined,
            actionLabel: 'Go to Blend Hub',
            onActionPressed: () => context.go('/blend'),
          ),
        ),
      );
    }

    final moodboardAsync = ref.watch(moodboardProvider(widget.groupId));

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: _buildAppBar(context),
      body: moodboardAsync.when(
        loading: () => Center(child: LoadingSkeletonShimmer(height: 400, radius: 20)),
        error: (err, _) => Center(
          child: AsyncRetryErrorState(
            title: 'Could not load moodboard',
            message: err.toString(),
            onRetry: () => ref.invalidate(moodboardProvider(widget.groupId)),
          ),
        ),
        data: (items) => _buildBody(context, items),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.trenzyColors.primary,
        foregroundColor: context.trenzyColors.primaryFg,
        onPressed: () => _showAddItemSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.trenzyColors.background,
      elevation: 0,
      leading: GlassBackButton(),
      title: Text('Moodboard', style: TextStyle(color: context.trenzyColors.foreground, fontWeight: FontWeight.bold)),
      actions: [
        PopupMenuButton<String>(
          color: context.trenzyColors.graphite,
          icon: Icon(Icons.filter_list_rounded, color: context.trenzyColors.mutedFg),
          onSelected: (value) => setState(() => _itemTypeFilter = value == 'all' ? null : value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'all', child: Text('All', style: TextStyle(color: _itemTypeFilter == null ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'product', child: Text('Products', style: TextStyle(color: _itemTypeFilter == 'product' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'image', child: Text('Images', style: TextStyle(color: _itemTypeFilter == 'image' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'note', child: Text('Notes', style: TextStyle(color: _itemTypeFilter == 'note' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'palette', child: Text('Palettes', style: TextStyle(color: _itemTypeFilter == 'palette' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<MoodboardItem> items) {
    final filtered = _itemTypeFilter != null && _itemTypeFilter!.isNotEmpty
        ? items.where((e) => e.itemType == _itemTypeFilter).toList()
        : items;

    if (filtered.isEmpty) {
      return FriendlyEmptyState(
        title: 'Moodboard is empty',
        message: 'Tap + to add inspiration images, products, notes, and color palettes',
        icon: Icons.palette_outlined,
        actionLabel: 'Add Inspiration',
        onActionPressed: () => _showAddItemSheet(context),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: filtered.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AddTile(onTap: () => _showAddItemSheet(context));
        }
        final item = filtered[index - 1];
        return _MoodboardTile(
          item: item,
          onTap: () => _showItemDetail(context, item),
          onRemove: () => _removeItem(item),
        );
      },
    );
  }

  void _removeItem(MoodboardItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        title: Text('Remove item?', style: TextStyle(color: context.trenzyColors.foreground)),
        content: Text('Remove this ${item.itemType.replaceAll('_', ' ')} from the moodboard?', style: TextStyle(color: context.trenzyColors.mutedFg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: context.trenzyColors.mutedFg)),
          ),
          TextButton(
            onPressed: () {
              ref.read(moodboardNotifierProvider.notifier).removeItem(
                blendId: widget.groupId,
                itemId: item.id,
              );
              Navigator.of(ctx).pop();
              ref.invalidate(moodboardProvider(widget.groupId));
            },
            child: Text('Remove', style: TextStyle(color: context.trenzyColors.crimson)),
          ),
        ],
      ),
    );
  }

  void _showItemDetail(BuildContext context, MoodboardItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.itemType.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, letterSpacing: 2, color: context.trenzyColors.primary, fontWeight: FontWeight.w700),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Icon(Icons.close_rounded, color: context.trenzyColors.mutedFg),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(imageUrl: item.imageUrl!, height: 250, width: double.infinity, fit: BoxFit.cover),
              ),
              SizedBox(height: 16),
            ],
              if (item.caption != null && item.caption!.isNotEmpty) ...[
                Text(item.caption!, style: TextStyle(fontSize: 16, color: context.trenzyColors.foreground)),
                SizedBox(height: 12),
              ],
              if (item.content != null && item.content!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.trenzyColors.glass,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.content!.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                    style: TextStyle(fontSize: 13, color: context.trenzyColors.mutedFg),
                  ),
                ),
                SizedBox(height: 12),
              ],
              Text('Added by ${item.addedByName}', style: TextStyle(fontSize: 11, color: context.trenzyColors.mutedFg)),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _removeItem(item);
                  },
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text('Remove from Moodboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.trenzyColors.crimson,
                    side: BorderSide(color: context.trenzyColors.crimson.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    final captionCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    String selectedType = 'image';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.trenzyColors.graphite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add to Moodboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground)),
                    GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: Icon(Icons.close_rounded, color: context.trenzyColors.mutedFg)),
                  ],
                ),
                SizedBox(height: 20),
                Text('Type', style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg)),
                SizedBox(height: 8),
                Row(
                  children: [
                    _TypeChip(label: 'Image', value: 'image', selected: selectedType == 'image', onTap: () => setState(() => selectedType = 'image')),
                    SizedBox(width: 8),
                    _TypeChip(label: 'Note', value: 'note', selected: selectedType == 'note', onTap: () => setState(() => selectedType = 'note')),
                    SizedBox(width: 8),
                    _TypeChip(label: 'Product', value: 'product', selected: selectedType == 'product', onTap: () => setState(() => selectedType = 'product')),
                    SizedBox(width: 8),
                    _TypeChip(label: 'Palette', value: 'palette', selected: selectedType == 'palette', onTap: () => setState(() => selectedType = 'palette')),
                  ],
                ),
                SizedBox(height: 16),
                if (selectedType == 'image' || selectedType == 'product' || selectedType == 'palette') ...[
                  TextField(
                    controller: imageUrlCtrl,
                    style: TextStyle(color: context.trenzyColors.foreground),
                    decoration: InputDecoration(
                      labelText: 'Image URL',
                      labelStyle: TextStyle(color: context.trenzyColors.mutedFg),
                      filled: true,
                      fillColor: context.trenzyColors.glass,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.glassBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.glassBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                TextField(
                  controller: captionCtrl,
                  maxLines: 3,
                  style: TextStyle(color: context.trenzyColors.foreground),
                  decoration: InputDecoration(
                    labelText: 'Caption (optional)',
                    labelStyle: TextStyle(color: context.trenzyColors.mutedFg),
                    filled: true,
                    fillColor: context.trenzyColors.glass,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.glassBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.glassBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.trenzyColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    label: 'Add to Moodboard',
                    onTap: () async {
                      final success = await ref.read(moodboardNotifierProvider.notifier).addItem(
                        blendId: widget.groupId,
                        itemType: selectedType,
                        imageUrl: imageUrlCtrl.text.trim().isEmpty ? null : imageUrlCtrl.text.trim(),
                        caption: captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim(),
                      );
                      if (success && ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ref.invalidate(moodboardProvider(widget.groupId));
                        GlassToast.success(context, 'Added to moodboard');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.trenzyColors.primary.withValues(alpha: 0.15) : context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? context.trenzyColors.primary.withValues(alpha: 0.5) : context.trenzyColors.glassBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? context.trenzyColors.primary : context.trenzyColors.mutedFg,
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.trenzyColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.trenzyColors.glassBorder, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: context.trenzyColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: context.trenzyColors.primary, size: 24),
            ),
            SizedBox(height: 8),
            Text('Add Inspiration', style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MoodboardTile extends StatelessWidget {
  final MoodboardItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MoodboardTile({required this.item, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover, width: double.infinity, placeholder: (_, _) => _itemPlaceholder(item, context), errorWidget: (_, _, _) => _itemPlaceholder(item, context)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.itemType.replaceAll('_', ' '), style: TextStyle(fontSize: 10, color: context.trenzyColors.mutedFg)),
                        if (item.caption != null && item.caption!.isNotEmpty)
                          Text(item.caption!, style: TextStyle(fontSize: 11, color: context.trenzyColors.foreground), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(Icons.close_rounded, size: 16, color: context.trenzyColors.mutedFg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemPlaceholder(MoodboardItem item, BuildContext context) {
    IconData icon;
    switch (item.itemType) {
      case 'note':
        icon = Icons.notes_rounded;
        break;
      case 'palette':
        icon = Icons.palette_outlined;
        break;
      case 'product':
        icon = Icons.shopping_bag_outlined;
        break;
      default:
        icon = Icons.image_outlined;
    }
    return Container(
      color: context.trenzyColors.glass,
      child: Center(child: Icon(icon, color: context.trenzyColors.mutedFg, size: 28)),
    );
  }
}
