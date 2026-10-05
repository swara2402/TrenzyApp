import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/models/wardrobe_model.dart';
import 'package:trenzy/providers/auth_provider.dart';
import 'package:trenzy/providers/home_providers.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/router/app_router.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/theme/trenzy_colors.dart';

class OutfitBuilderScreen extends ConsumerStatefulWidget {
  final Outfit? initialOutfit;
  const OutfitBuilderScreen({super.key, this.initialOutfit});

  @override
  ConsumerState<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  final List<_ItemData> _canvasItems = [];
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOutfit != null) {
      _nameController.text = widget.initialOutfit!.name;
      if (widget.initialOutfit!.items.isNotEmpty == true) {
        for (final item in widget.initialOutfit!.items) {
          final itemId = int.tryParse(item.id) ?? 0;
          if (itemId > 0) {
            _canvasItems.add(_ItemData(
              itemId,
              item.brand.isEmpty ? 'Unknown' : item.brand,
              item.name,
              item.imageUrl,
            ));
          }
        }
      }
    }
  }

  void _addItemToCanvas(_ItemData item) {
    setState(() {
      _canvasItems.add(item);
    });
  }

  void _removeItemFromCanvas(int index) {
    setState(() {
      _canvasItems.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveOutfit() async {
    if (_canvasItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add items to your outfit before saving')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name your look before saving')),
      );
      return;
    }

    final ids = _canvasItems.map((item) => item.id).where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected items do not have valid IDs')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final outfitId = widget.initialOutfit != null ? int.tryParse(widget.initialOutfit!.id) : null;

      if (outfitId != null && outfitId > 0) {
        await api.updateOutfit(
          outfitId,
          name: name,
          wardrobeItemIds: ids,
        );
      } else {
        await api.createOutfit(
          name: name,
          wardrobeItemIds: ids,
        );
      }

      ref.invalidate(outfitsProvider);
      ref.invalidate(wardrobeRecommendationsProvider);
      ref.invalidate(aiOutfitMatchesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Look saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save look: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const _CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildDigitalCanvas(context),
              const SizedBox(height: 48),
              _buildWardrobeSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _BottomNavBar(),
    );
  }

  Widget _buildHeader() {
    final colors = context.trenzyColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CREATIVE SUITE',
          style: TextStyle(
            color: colors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.initialOutfit != null ? 'Edit Outfit' : 'Outfit Builder',
              style: TextStyle(
                color: colors.foreground,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveOutfit,
                  icon: _isSaving
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primaryFg,
                          ),
                        )
                      : Icon(Icons.save, color: colors.primary, size: 20),
                  label: Text(_isSaving ? 'SAVING...' : 'SAVE LOOK'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: colors.foreground,
                    backgroundColor: colors.graphite,
                    disabledBackgroundColor: colors.graphite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                      side: BorderSide(color: colors.fg15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _buildDigitalCanvas(BuildContext context) {
    return DragTarget<_ItemData>(
      onAcceptWithDetails: (details) => _addItemToCanvas(details.data),
      builder: (context, candidateData, rejectedData) {
        final colors = context.trenzyColors;
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withAlpha(5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(153),
                  blurRadius: 64,
                  offset: const Offset(0, 32),
                ),
              ],
            ),
            child: Stack(
              children: [
                const GridPattern(),
                if (_canvasItems.isEmpty)
                  Center(
                    child: Container(
                      width: 224,
                      height: 288,
                      decoration: BoxDecoration(
                        color: context.trenzyColors.surfaceContainer.withAlpha(51),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: context.trenzyColors.mutedFg.withAlpha(76),
                            style: BorderStyle.solid,
                            width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: context.trenzyColors.primary, size: 50),
                          const SizedBox(height: 12),
                          Text(
                            'DROP ITEMS HERE',
                            style: TextStyle(
                              color: context.trenzyColors.mutedFg,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  else
                  ..._canvasItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Positioned(
                      left: 20.0 + (index % 4) * 50,
                      top: 20.0 + (index / 4).floor() * 50,
                      child: GestureDetector(
                        onDoubleTap: () => _removeItemFromCanvas(index),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 130,
                              height: 160,
                              child: item.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.contain,
                                      errorWidget: (_, _, _) => Container(
                                        color: colors.surfaceContainer,
                                        child: Icon(Icons.checkroom, color: colors.primary),
                                      ),
                                    )
                                  : Container(
                                      color: colors.surfaceContainer,
                                      child: Icon(Icons.checkroom, color: colors.primary),
                                    ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removeItemFromCanvas(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                Positioned(
                  bottom: 32,
                  right: MediaQuery.of(context).size.width * 0.05,
                  child: _buildLookIdentityCard(),
                ),
                const Center(
                  child: Text(
                    'STUDIO',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: Color.fromRGBO(255, 255, 255, 0.03),
                      letterSpacing: -2,
                    ),
                  ),
                ),
                ],
              ),
            ),
          );
        },
      );
  }

  Widget _buildLookIdentityCard() {
    final colors = context.trenzyColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withAlpha(178),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOOK IDENTITY',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 192,
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(color: colors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Name Your Look...',
                    hintStyle: TextStyle(color: colors.mutedFg.withAlpha(178)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.fg15),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.primary),
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

  Widget _buildWardrobeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Wardrobe',
              style: TextStyle(
                color: context.trenzyColors.foreground,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.trenzyColors.fg15),
              ),
              child: Icon(Icons.tune, color: context.trenzyColors.mutedFg),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildCategoryChips(),
        const SizedBox(height: 32),
        _buildItemGrid(),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All Items', 'Tops', 'Bottoms', 'Outerwear', 'Footwear', 'Accessories'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          bool isActive = category == 'All Items';
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                foregroundColor: isActive ? context.trenzyColors.primaryFg : context.trenzyColors.foreground,
                backgroundColor: isActive ? context.trenzyColors.primary : context.trenzyColors.graphite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                  side: isActive ? BorderSide.none : BorderSide(color: context.trenzyColors.fg15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              child: Text(category.toUpperCase()),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemGrid() {
    final wardrobeAsync = ref.watch(wardrobeProvider);

    return wardrobeAsync.when(
      data: (state) {
        final items = state.items;
        if (items.isEmpty) {
          return _buildEmptyWardrobe();
        }
        final itemDataList = items
            .map((w) {
              final parsedId = int.tryParse(w.id) ?? 0;
              return _ItemData(
                parsedId,
                w.brand,
                w.name,
                w.imageUrl,
              );
            })
            .where((item) => item.id > 0)
            .toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 40,
            childAspectRatio: 3 / 4.5,
          ),
          itemCount: itemDataList.length + 1,
          itemBuilder: (context, index) {
            if (index == itemDataList.length) {
              return _buildAddItemCard();
            }
            final item = itemDataList[index];
            return Draggable<_ItemData>(
              data: item,
              feedback: SizedBox(
                width: 100,
                height: 100,
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.contain)
                    : Icon(Icons.checkroom, color: context.trenzyColors.primary),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _ItemCard(
                  item: item,
                  onAdd: () => _addItemToCanvas(item),
                ),
              ),
              child: _ItemCard(
                item: item,
                onAdd: () => _addItemToCanvas(item),
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: context.trenzyColors.primary),
      ),
      error: (_, e) => _buildEmptyWardrobe(),
    );
  }

  Widget _buildEmptyWardrobe() {
    final colors = context.trenzyColors;
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.checkroom, color: colors.mutedFg.withAlpha(102), size: 48),
          const SizedBox(height: 16),
          Text(
            'Your wardrobe is empty',
            style: TextStyle(color: colors.mutedFg, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to your wardrobe to start building outfits',
            style: TextStyle(color: colors.fg50, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemCard() {
    final colors = context.trenzyColors;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.addItem),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.fg15.withAlpha(128), style: BorderStyle.solid, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.graphite,
              ),
              child: Icon(Icons.upload, color: colors.mutedFg),
            ),
            const SizedBox(height: 12),
            Text(
              'NEW ITEM',
              style: TextStyle(
                color: colors.mutedFg,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _CustomAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    final colors = context.trenzyColors;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: colors.background.withAlpha(204),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 150,
            leading: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.graphite,
                  backgroundImage: (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: (user?.avatarUrl == null || user!.avatarUrl.isEmpty)
                      ? Text(
                          (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Trenzy',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_none, color: colors.mutedFg),
                onPressed: () => context.push(AppRoutes.notifications),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    final colors = context.trenzyColors;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: colors.background.withAlpha(230),
            border: Border(top: BorderSide(color: colors.fg10.withAlpha(51))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.home, 'Home', AppRoutes.home, isActive: currentRoute == AppRoutes.home),
              _buildNavItem(context, Icons.search, 'Explore', AppRoutes.search, isActive: currentRoute == AppRoutes.search),
              _buildNavItem(context, Icons.style, 'Inspo', AppRoutes.inspo, isActive: currentRoute == AppRoutes.inspo),
              _buildNavItem(context, Icons.shopping_bag, 'Closet', AppRoutes.wardrobe, isActive: currentRoute == AppRoutes.wardrobe),
              _buildNavItem(context, Icons.person, 'Profile', AppRoutes.profile, isActive: currentRoute == AppRoutes.profile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route, {bool isActive = false}) {
    final colors = context.trenzyColors;
    return GestureDetector(
      onTap: () => GoRouter.of(context).go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? colors.primary : colors.foreground.withAlpha(102),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isActive ? colors.primary : colors.foreground.withAlpha(102),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemData {
  final int id;
  final String brand;
  final String name;
  final String imageUrl;

  _ItemData(this.id, this.brand, this.name, this.imageUrl);
}

class _ItemCard extends StatelessWidget {
  final _ItemData item;
  final VoidCallback? onAdd;

  const _ItemCard({required this.item, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(13)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: context.trenzyColors.surfaceContainer,
                              child: Icon(Icons.checkroom, color: context.trenzyColors.primary, size: 40),
                            ),
                          )
                        : Container(
                            color: context.trenzyColors.surfaceContainer,
                            child: Icon(Icons.checkroom, color: context.trenzyColors.primary, size: 40),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withAlpha(180), Colors.transparent],
                        ),
                      ),
                      child: GestureDetector(
                        onTap: onAdd,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              width: double.infinity,
                              color: Colors.white.withAlpha(51),
                              child: const Text(
                                'ADD TO LOOK',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            item.brand.toUpperCase(),
            style: TextStyle(
              color: context.trenzyColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            item.name,
            style: TextStyle(
              color: context.trenzyColors.foreground,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class GridPattern extends StatelessWidget {
  const GridPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: Container(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD79D8A).withAlpha(13)  // rose-gold grid lines
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 32) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 32) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}