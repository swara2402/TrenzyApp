// ignore_for_file: dead_code
// ignore_for_file: dead_null_aware_expression
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trenzy/models/wardrobe_model.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/home_providers.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/widgets/section_states.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditClothingScreen extends ConsumerStatefulWidget {
  final WardrobeItem item;
  const EditClothingScreen({super.key, required this.item});

  @override
  ConsumerState<EditClothingScreen> createState() => _EditClothingScreenState();
}

class _EditClothingScreenState extends ConsumerState<EditClothingScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _colorController = TextEditingController();

  String _selectedCategory = 'Tops';
  String _selectedSeason = 'FALL';
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  static const categories = [
    'Tops',
    'Bottoms',
    'Outerwear',
    'Dresses',
    'Shoes',
    'Accessories',
  ];

  static const seasons = ['SPRING', 'SUMMER', 'FALL', 'WINTER'];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.item.name;
    _brandController.text = widget.item.brand ?? '';
    _imageUrlController.text = widget.item.imageUrl ?? '';
    _colorController.text = widget.item.color ?? '';
    _selectedCategory = widget.item.category ?? 'Tops';
    _selectedSeason = widget.item.season ?? 'FALL';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    final imageUrl = _imageUrlController.text.trim();
    if (imageUrl.isNotEmpty &&
        !(imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image URL must start with http:// or https://')),
      );
      return;
    }

    final brand = _brandController.text.trim();
    final color = _colorController.text.trim();

    if (name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name cannot exceed 50 characters')),
      );
      return;
    }
    if (brand.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand cannot exceed 50 characters')),
      );
      return;
    }
    if (color.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Color cannot exceed 30 characters')),
      );
      return;
    }
    if (imageUrl.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image URL cannot exceed 500 characters')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final color = _colorController.text.trim();

      await api.updateWardrobeItem(
        int.parse(widget.item.id),
        name: name,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        color: color.isNotEmpty ? color : null,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        category: _selectedCategory,
        season: _selectedSeason,
      );

      ref.invalidate(wardrobeProvider);
      ref.invalidate(wardrobeRecommendationsProvider);
      ref.invalidate(aiOutfitMatchesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteItem() async {
    setState(() => _isDeleting = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteWardrobeItem(int.parse(widget.item.id));

      ref.invalidate(wardrobeProvider);
      ref.invalidate(wardrobeRecommendationsProvider);
      ref.invalidate(aiOutfitMatchesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);
      final api = ref.read(apiServiceProvider);
      final imageUrl = await api.uploadImage(image);

      setState(() {
        _imageUrlController.text = imageUrl;
        _isUploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${friendlyError(e)}')),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      appBar: AppBar(
        backgroundColor: context.trenzyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.trenzyColors.foreground),
          onPressed: () => context.pop(),
        ),
        title: DisplayText(
          'Edit Item',
          fontSize: 20,
          weight: FontWeight.w600,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildImageUpload(),
            const SizedBox(height: 32),
            _buildForm(),
            const SizedBox(height: 48),
            _buildSaveButton(),
            const SizedBox(height: 16),
            _buildDeleteButton(),
            const SizedBox(height: 24),
            Text(
              'Changes will be synced to your digital twin'.toUpperCase(),
              style: GlassTypography.body(
                color: context.trenzyColors.mutedFg.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUpload() {
    final url = _imageUrlController.text.trim();
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.trenzyColors.graphite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.trenzyColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isUploading
            ? Center(
                child: CircularProgressIndicator(
                  color: context.trenzyColors.primary,
                ),
              )
            : Stack(
                children: [
                  if (url.isNotEmpty &&
                      (url.startsWith('http://') || url.startsWith('https://')))
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                color: context.trenzyColors.mutedFg,
                                size: 40),
                            const SizedBox(height: 8),
                            Text('Invalid Image URL',
                                style: TextStyle(
                                    color: context.trenzyColors.mutedFg,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.trenzyColors.fg40,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.image_search_rounded,
                            color: context.trenzyColors.mutedFg,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to Upload Image'.toUpperCase(),
                          style: GlassTypography.body(
                            color: context.trenzyColors.mutedFg,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  if (url.isNotEmpty && !_isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(Icons.clear, color: context.trenzyColors.foreground),
                        onPressed: () {
                          setState(() {
                            _imageUrlController.clear();
                          });
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Item Name',
          placeholder: 'e.g. Tailored Blazer',
          controller: _nameController,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Image URL',
          placeholder: 'https://example.com/image.jpg',
          controller: _imageUrlController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Brand',
                placeholder: 'Designer',
                controller: _brandController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                label: 'Color',
                placeholder: 'e.g. Black',
                controller: _colorController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Category',
          value: _selectedCategory,
          items: categories,
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        const SizedBox(height: 20),
        _buildSeasonSelector(),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GlassTypography.body(
            color: context.trenzyColors.mutedFg,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(color: context.trenzyColors.foreground),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.trenzyColors.graphite,
            hintText: placeholder,
            hintStyle: TextStyle(color: context.trenzyColors.fg40),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GlassTypography.body(
            color: context.trenzyColors.mutedFg,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((String v) {
            return DropdownMenuItem<String>(value: v, child: Text(v));
          }).toList(),
          onChanged: onChanged,
          style: TextStyle(color: context.trenzyColors.foreground),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.trenzyColors.graphite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: context.trenzyColors.graphite,
        ),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Season'.toUpperCase(),
          style: GlassTypography.body(
            color: context.trenzyColors.mutedFg,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: seasons.map((season) {
            final isSelected = _selectedSeason == season;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: season != seasons.last ? 8 : 0,
                ),
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedSeason = season),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? context.trenzyColors.primary.withValues(alpha: 0.1)
                        : context.trenzyColors.graphite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(
                              color: context.trenzyColors.primary
                                  .withValues(alpha: 0.3),
                            )
                          : BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    season,
                    style: TextStyle(
                      color: isSelected
                          ? context.trenzyColors.primary
                          : context.trenzyColors.mutedFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveItem,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF3C2F00),
              ),
            )
          : const Icon(Icons.checkroom, color: Color(0xFF3C2F00)),
      label: Text(
        _isSaving ? 'Saving...' : 'Save Changes',
        style: const TextStyle(
          color: Color(0xFF3C2F00),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.trenzyColors.primary,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        disabledBackgroundColor:
            context.trenzyColors.primary.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      onPressed: _isDeleting
          ? null
          : () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Item'),
                  content:
                      const Text('Are you sure you want to delete this item?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _deleteItem();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
      icon: _isDeleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.redAccent,
              ),
            )
          : const Icon(Icons.delete_outline, color: Colors.redAccent),
      label: Text(
        _isDeleting ? 'Deleting...' : 'Delete Item',
        style: const TextStyle(color: Colors.redAccent),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }
}