import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  String? _imageUrl;
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();

  bool get _canPost => _imageUrl != null;

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _handleShare() {
    if (!_canPost) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared!')),
    );
    context.pop();
  }

  void _handleSelectImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera & gallery integration coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16130B),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageArea(),
            _buildCaptionInput(),
            _buildTagProductsSection(),
            _buildAddLocationTile(),
            const SizedBox(height: 24),
            _buildShareButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFFEAE1D4)),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'New Post',
        style: TextStyle(
          color: Color(0xFFEAE1D4),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _canPost ? _handleShare : null,
          child: Text(
            'Post',
            style: TextStyle(
              color: _canPost
                  ? const Color(0xFFF2CA50)
                  : const Color(0xFFD0C5AF).withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageArea() {
    return GestureDetector(
      onTap: _handleSelectImage,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF231F17),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _imageUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFFEAE1D4),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildImagePlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFFF2CA50),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap to add photo',
              style: TextStyle(
                color: Color(0xFFD0C5AF),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _captionController,
        focusNode: _captionFocusNode,
        maxLines: 5,
        minLines: 1,
        style: const TextStyle(color: Color(0xFFEAE1D4), fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Write a caption...',
          hintStyle: const TextStyle(color: Color(0xFFD0C5AF)),
          filled: true,
          fillColor: const Color(0xFF2C2A24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF2CA50), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildTagProductsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tag Products',
            style: TextStyle(
              color: Color(0xFFF2CA50),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildAddProductChip(),
                const SizedBox(width: 8),
                _buildAddProductChip(),
                const SizedBox(width: 8),
                _buildAddProductChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProductChip() {
    final goldWithAlpha = const Color(0xFFF2CA50).withValues(alpha: 0.3);
    return ActionChip(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product tagging coming soon')),
        );
      },
      avatar: const Icon(Icons.add, size: 18, color: Color(0xFFF2CA50)),
      label: const Text(
        'Tag Product',
        style: TextStyle(color: Color(0xFFF2CA50), fontSize: 13),
      ),
      backgroundColor: const Color(0xFF231F17),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(color: goldWithAlpha),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildAddLocationTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ListTile(
        leading: const Icon(
          Icons.location_on_outlined,
          color: Color(0xFFD0C5AF),
        ),
        title: const Text(
          'Add Location',
          style: TextStyle(
            color: Color(0xFFD0C5AF),
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFD0C5AF),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location picker coming soon')),
          );
        },
      ),
    );
  }

  Widget _buildShareButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _canPost ? _handleShare : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF2CA50),
            disabledBackgroundColor: const Color(0xFFD0C5AF).withValues(alpha: 0.2),
            foregroundColor: const Color(0xFF241A00),
            disabledForegroundColor: const Color(0xFFD0C5AF).withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Share',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0C5AF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.0, 1.0, size.width - 2.0, size.height - 2.0),
      const Radius.circular(20),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 8.0;
        final clampedEnd = end > metric.length ? metric.length : end;
        final segment = metric.extractPath(distance, clampedEnd);
        canvas.drawPath(segment, paint);
        distance += 14.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
