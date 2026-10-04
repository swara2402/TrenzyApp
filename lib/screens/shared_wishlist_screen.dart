import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/blend_model.dart';
import '../providers/blend_dashboard_provider.dart';
import '../theme/glass_theme.dart';

class SharedWishlistScreen extends ConsumerStatefulWidget {
  const SharedWishlistScreen({super.key, this.groupId = ''});

  final String groupId;

  @override
  ConsumerState<SharedWishlistScreen> createState() => _SharedWishlistScreenState();
}

class _SharedWishlistScreenState extends ConsumerState<SharedWishlistScreen> {
  String _sortBy = 'newest';
  String? _categoryFilter;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId.isEmpty) {
      return Scaffold(
        backgroundColor: context.trenzyColors.background,
        body: Center(
          child: FriendlyEmptyState(
            title: 'No blend selected',
            message: 'Join or create a blend to see shared wishlist',
            icon: Icons.favorite_outline_rounded,
            actionLabel: 'Go to Blend Hub',
            onActionPressed: () => context.go('/blend'),
          ),
        ),
      );
    }

    final wishlistAsync = ref.watch(sharedWishlistProvider(widget.groupId));

    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: _buildAppBar(context),
      body: wishlistAsync.when(
        loading: () => Center(child: LoadingSkeletonShimmer(height: 400, radius: 20)),
        error: (err, _) => Center(
          child: AsyncRetryErrorState(
            title: 'Could not load wishlist',
            message: err.toString(),
            onRetry: () => ref.invalidate(sharedWishlistProvider(widget.groupId)),
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
      title: Text('Shared Wishlist', style: TextStyle(color: context.trenzyColors.foreground, fontWeight: FontWeight.bold)),
      actions: [
        PopupMenuButton<String>(
          color: context.trenzyColors.graphite,
          icon: Icon(Icons.sort_rounded, color: context.trenzyColors.mutedFg),
          onSelected: (value) => setState(() => _sortBy = value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'newest', child: Text('Newest', style: TextStyle(color: _sortBy == 'newest' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'oldest', child: Text('Oldest', style: TextStyle(color: _sortBy == 'oldest' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'name', child: Text('Name', style: TextStyle(color: _sortBy == 'name' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'price_high', child: Text('Price: High to Low', style: TextStyle(color: _sortBy == 'price_high' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
            PopupMenuItem(value: 'price_low', child: Text('Price: Low to High', style: TextStyle(color: _sortBy == 'price_low' ? context.trenzyColors.primary : context.trenzyColors.foreground))),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<SharedWishlistItem> items) {
    final filtered = _applyFilters(items);

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(child: filtered.isEmpty ? _buildEmptyState(context) : _buildWishlistGrid(context, filtered)),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassSearchBar(
        controller: _searchController,
        hintText: 'Search wishlist...',
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        trailing: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close_rounded, size: 18, color: context.trenzyColors.mutedFg),
              )
            : null,
      ),
    );
  }

  Widget _buildWishlistGrid(BuildContext context, List<SharedWishlistItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) => _WishlistItemCard(
        item: items[index],
        onToggleFavorite: () => _toggleFavorite(items[index]),
        onRemove: () => _removeItem(items[index]),
        onTap: () => _showItemDetails(context, items[index]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return FriendlyEmptyState(
      title: 'Wishlist is empty',
      message: 'Tap + to add items you both love',
      icon: Icons.favorite_outline_rounded,
      actionLabel: 'Add Item',
      onActionPressed: () => _showAddItemSheet(context),
    );
  }

  List<SharedWishlistItem> _applyFilters(List<SharedWishlistItem> items) {
    var result = items.toList();

    if (_searchQuery.isNotEmpty) {
      result = result.where((e) =>
        e.productName.toLowerCase().contains(_searchQuery) ||
        (e.productBrand?.toLowerCase().contains(_searchQuery) ?? false) ||
        (e.productCategory?.toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }

    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      result = result.where((e) => e.productCategory == _categoryFilter).toList();
    }

    switch (_sortBy) {
      case 'oldest':
        result.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
        break;
      case 'name':
        result.sort((a, b) => a.productName.compareTo(b.productName));
        break;
      case 'price_high':
        result.sort((a, b) => (b.productPrice ?? 0).compareTo(a.productPrice ?? 0));
        break;
      case 'price_low':
        result.sort((a, b) => (a.productPrice ?? 0).compareTo(b.productPrice ?? 0));
        break;
      default:
        result.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    }

    return result;
  }

  void _toggleFavorite(SharedWishlistItem item) {
    ref.read(blendWishlistNotifierProvider.notifier).updateItem(
      blendId: widget.groupId,
      itemId: item.id,
      isFavorite: !item.isFavorite,
    );
  }

  void _removeItem(SharedWishlistItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.trenzyColors.graphite,
        title: Text('Remove item?', style: TextStyle(color: context.trenzyColors.foreground)),
        content: Text('Remove "${item.productName}" from shared wishlist?', style: TextStyle(color: context.trenzyColors.mutedFg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: context.trenzyColors.mutedFg)),
          ),
          TextButton(
            onPressed: () {
              ref.read(blendWishlistNotifierProvider.notifier).removeItem(
                blendId: widget.groupId,
                itemId: item.id,
              );
              Navigator.of(ctx).pop();
              ref.invalidate(sharedWishlistProvider(widget.groupId));
            },
            child: Text('Remove', style: TextStyle(color: context.trenzyColors.crimson)),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(BuildContext context, SharedWishlistItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ItemDetailsSheet(
        item: item,
        onToggleFavorite: () => _toggleFavorite(item),
        onRemove: () {
          Navigator.of(ctx).pop();
          _removeItem(item);
        },
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    Text('Add to Wishlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground)),
                    GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: Icon(Icons.close_rounded, color: context.trenzyColors.mutedFg)),
                  ],
                ),
                SizedBox(height: 20),
                _buildTextField(context, 'Product Name', nameCtrl),
                SizedBox(height: 12),
                _buildTextField(context, 'Price (optional)', priceCtrl, keyboardType: TextInputType.number),
                SizedBox(height: 12),
                _buildTextField(context, 'Brand (optional)', brandCtrl),
                SizedBox(height: 12),
                _buildTextField(context, 'Category (optional)', categoryCtrl),
                SizedBox(height: 12),
                _buildTextField(context, 'Image URL (optional)', imageCtrl),
                SizedBox(height: 12),
                _buildTextField(context, 'Product URL (optional)', urlCtrl),
                SizedBox(height: 12),
                _buildTextField(context, 'Notes (optional)', notesCtrl, maxLines: 3),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    label: 'Add to Wishlist',
                    onTap: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final success = await ref.read(blendWishlistNotifierProvider.notifier).addItem(
                        blendId: widget.groupId,
                        productId: DateTime.now().millisecondsSinceEpoch.toString(),
                        productName: name,
                        productPrice: double.tryParse(priceCtrl.text),
                        productImage: imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                        productBrand: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                        productCategory: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                        productUrl: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                      if (success && ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ref.invalidate(sharedWishlistProvider(widget.groupId));
                        GlassToast.success(context, 'Added to wishlist');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      priceCtrl.dispose();
      brandCtrl.dispose();
      categoryCtrl.dispose();
      imageCtrl.dispose();
      urlCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController ctrl, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: context.trenzyColors.foreground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.trenzyColors.mutedFg),
        filled: true,
        fillColor: context.trenzyColors.glass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.trenzyColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.trenzyColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.trenzyColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _WishlistItemCard extends StatelessWidget {
  final SharedWishlistItem item;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _WishlistItemCard({
    required this.item,
    required this.onToggleFavorite,
    required this.onRemove,
    required this.onTap,
  });

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  item.productImage != null
                      ? CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover, width: double.infinity, placeholder: (_, _) => Container(color: context.trenzyColors.glass), errorWidget: (_, _, _) => _PlaceholderIcon())
                      : _PlaceholderIcon(),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.trenzyColors.glass,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: item.isFavorite ? context.trenzyColors.crimson : context.trenzyColors.mutedFg,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: TextStyle(fontWeight: FontWeight.w600, color: context.trenzyColors.foreground, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (item.productBrand != null)
                      Text(item.productBrand!, style: TextStyle(fontSize: 10, color: context.trenzyColors.mutedFg)),
                    if (item.productPrice != null) ...[
                      SizedBox(height: 2),
                      Text('₹${item.productPrice!.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.trenzyColors.primary)),
                    ],
                    Spacer(),
                    Row(
                      children: [
                        Text(item.addedByName, style: TextStyle(fontSize: 9, color: context.trenzyColors.mutedFg)),
                        Spacer(),
                        GestureDetector(
                          onTap: onRemove,
                          child: Icon(Icons.delete_outline, size: 14, color: context.trenzyColors.mutedFg),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.trenzyColors.glass,
      child: Center(child: Icon(Icons.shopping_bag_outlined, color: context.trenzyColors.mutedFg, size: 28)),
    );
  }
}

class _ItemDetailsSheet extends StatelessWidget {
  final SharedWishlistItem item;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;

  const _ItemDetailsSheet({
    required this.item,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Expanded(
                  child: Text(item.productName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.trenzyColors.foreground)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close_rounded, color: context.trenzyColors.mutedFg),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (item.productImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(imageUrl: item.productImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              SizedBox(height: 16),
            ],
            if (item.productBrand != null) ...[
              Text('Brand:', style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg)),
              Text(item.productBrand!, style: TextStyle(fontSize: 16, color: context.trenzyColors.foreground)),
              SizedBox(height: 8),
            ],
            if (item.productPrice != null) ...[
              Text('Price:', style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg)),
              Text('₹${item.productPrice!.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.trenzyColors.primary)),
              SizedBox(height: 8),
            ],
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              Text('Notes:', style: TextStyle(fontSize: 12, color: context.trenzyColors.mutedFg)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: context.trenzyColors.glass,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item.notes!, style: TextStyle(color: context.trenzyColors.foreground)),
              ),
              SizedBox(height: 8),
            ],
            Text('Added by ${item.addedByName}', style: TextStyle(fontSize: 11, color: context.trenzyColors.mutedFg)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GlowButton(
                    label: item.isFavorite ? 'Favorited' : 'Mark Favorite',
                    icon: item.isFavorite ? Icons.favorite : Icons.favorite_border,
                    onTap: () {
                      onToggleFavorite();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRemove();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.trenzyColors.crimson,
                      side: BorderSide(color: context.trenzyColors.crimson.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Remove'),
                  ),
                ),
              ],
            ),
            if (item.productUrl != null && item.productUrl!.isNotEmpty) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.open_in_new, size: 16),
                  label: Text('View Product'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.trenzyColors.primary,
                    side: BorderSide(color: context.trenzyColors.primary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
