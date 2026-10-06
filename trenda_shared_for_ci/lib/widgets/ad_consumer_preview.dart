// File: lib/widgets/ad_consumer_preview.dart
// Shows advertisers how their ad will look in the consumer-facing carousel
import 'package:flutter/material.dart';
import '../core/images/picked_image.dart';

class AdConsumerPreview extends StatelessWidget {
  final String title;
  final String businessName;
  final String? description;
  final List<PickedImage> photos;
  final bool featured;

  const AdConsumerPreview({
    super.key,
    required this.title,
    required this.businessName,
    this.description,
    required this.photos,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = title.isNotEmpty || businessName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(
          children: [
            Icon(Icons.visibility, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Consumer Preview',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Tap to expand',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Preview Card (tappable) ──
        GestureDetector(
          onTap: () => _showFullPreview(context),
          child: _buildPreviewCard(context, hasContent),
        ),
        const SizedBox(height: 6),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Container(
              width: i == 0 ? 14 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == 0 ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context, bool hasContent, {double height = 160}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade200,
        image: photos.isNotEmpty
            ? DecorationImage(image: MemoryImage(photos.first.bytes), fit: BoxFit.cover)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasContent) ...[
                  Text(
                    title.isNotEmpty ? title : 'Your Ad Title',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  ),
                  if (businessName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                ] else
                  Text(
                    'Fill in your ad details to see a preview',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          // Sponsored / Featured badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: featured ? Colors.amber.shade700 : Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (featured) ...[
                    const Icon(Icons.star, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    featured ? 'Featured' : 'Sponsored',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // No photo placeholder
          if (photos.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 2),
                  Text('Add a photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Fullscreen Preview Dialog ──
  void _showFullPreview(BuildContext context) {
    final hasContent = title.isNotEmpty || businessName.isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Ad Preview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Larger preview
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPreviewCard(ctx, hasContent, height: 260),
            ),
            // Description below
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ),
            // Photo gallery
            if (photos.length > 1) ...[
              SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: photos.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(photos[i].bytes, width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (photos.length <= 1) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
