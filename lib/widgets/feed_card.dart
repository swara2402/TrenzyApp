import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trenzy/models/feed_item.dart';
import 'package:trenzy/screens/feed_detail_screen.dart';
import 'package:trenzy/theme/glass_theme.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      closedColor: context.trenzyColors.background,
      openColor: context.trenzyColors.background,
      middleColor: context.trenzyColors.background,
      closedElevation: 0,
      openElevation: 0,
      transitionType: ContainerTransitionType.fade,
      transitionDuration: Duration(milliseconds: 500),
      closedBuilder: (context, action) {
        return Card(
          color: context.trenzyColors.graphite,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: context.trenzyColors.graphite,
                    child: Center(child: Icon(Icons.image_outlined, color: context.trenzyColors.mutedFg)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: context.trenzyColors.graphite,
                    child: Icon(Icons.broken_image, color: context.trenzyColors.mutedFg),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: context.trenzyColors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(color: context.trenzyColors.mutedFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      openBuilder: (context, action) {
        return FeedDetailScreen(item: item);
      },
    );
  }
}
