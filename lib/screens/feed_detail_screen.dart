import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trenzy/models/feed_item.dart';
import 'package:trenzy/theme/glass_theme.dart';

class FeedDetailScreen extends StatelessWidget {
  const FeedDetailScreen({super.key, required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.trenzyColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassBackButton(),
              ),
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 800,
                placeholder: (context, url) => Container(
                  height: 300,
                  color: context.trenzyColors.graphite,
                  child: Center(child: Icon(Icons.image_outlined, color: context.trenzyColors.mutedFg)),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  color: context.trenzyColors.graphite,
                  child: Icon(Icons.broken_image, color: context.trenzyColors.mutedFg),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GlassTypography.display(
                        fontSize: 24,
                        color: context.trenzyColors.foreground,
                        weight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      item.description,
                      style: GlassTypography.body(
                        fontSize: 16,
                        color: context.trenzyColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
