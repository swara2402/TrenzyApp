import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenzy/providers/api_service_provider.dart';
import 'package:trenzy/providers/home_providers.dart';
import 'package:trenzy/providers/wardrobe_provider.dart';
import 'package:trenzy/theme/glass_theme.dart';
import 'package:trenzy/widgets/section_states.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _colorController = TextEditingController();

  String _selectedCategory = 'Tops';
  String _selectedSeason = 'FALL';
  bool _isSaving = false;

  static const _categories = [
    'Tops',
    'Bottoms',
    'Outerwear',
    'Dresses',
    'Shoes',
    'Accessories',
  ];

  static const _seasons = ['SPRING', 'SUMMER', 'FALL', 'WINTER'];

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

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final color = _colorController.text.trim();

      await api.addWardrobeItem(
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
          const SnackBar(content: Text('Saved to wardrobe')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          'New Item',
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
            _buildImagePlaceholder(),
            const SizedBox(height: 32),
            _buildForm(),
            const SizedBox(height: 48),
            _buildSaveButton(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    final url = _imageUrlController.text.trim();
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.trenzyColors.graphite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.trenzyColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: context.trenzyColors.mutedFg, size: 40),
                    const SizedBox(height: 8),
                    Text('Invalid Image URL', style: TextStyle(color: context.trenzyColors.mutedFg, fontSize: 12)),
                  ],
                ),
              ),
            )
          : Column(
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
                  'Enter Image URL Below'.toUpperCase(),
                  style: GlassTypography.body(
                    color: context.trenzyColors.mutedFg,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
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
          items: _categories,
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
          children: _seasons.map((season) {
            final isSelected = _selectedSeason == season;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: season != _seasons.last ? 8 : 0,
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
        _isSaving ? 'Saving...' : 'Save to Wardrobe',
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
}