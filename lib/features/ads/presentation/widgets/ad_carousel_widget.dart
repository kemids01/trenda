// lib/features/ads/presentation/widgets/ad_carousel_widget.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/ad_model.dart';
import '../../utils/ad_click_handler.dart';

class AdCarouselWidget extends StatefulWidget {
  final List<AdModel> ads;
  final double height;
  final bool autoPlay;

  const AdCarouselWidget({
    super.key,
    required this.ads,
    this.height = 160,
    this.autoPlay = true,
  });

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget> {
  int _currentIndex = 0;
  final Set<String> _trackedIds = {};

  @override
  void initState() {
    super.initState();
    // Count an impression for the first ad shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.ads.isNotEmpty) {
        recordAdImpression(widget.ads.first, _trackedIds);
      }
    });
  }

  String _getOptimizedImageUrl(String url) {
    if (!url.contains('res.cloudinary.com')) return url;
    // Insert w_800,q_auto,f_auto for optimized loading
    // Format: https://res.cloudinary.com/cloud_name/image/upload/v1234/ads/file.jpg
    final parts = url.split('/upload/');
    if (parts.length == 2) {
      // If it already contains transformations, just return
      if (parts[1].startsWith('c_') || parts[1].startsWith('w_') || parts[1].startsWith('q_')) {
        return url;
      }
      return '${parts[0]}/upload/w_800,q_auto,f_auto/${parts[1]}';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: widget.height,
            autoPlay: widget.autoPlay,
            viewportFraction: 0.9,
            enlargeCenterPage: true,
            onPageChanged: (index, _) {
              setState(() => _currentIndex = index);
              if (index >= 0 && index < widget.ads.length) {
                recordAdImpression(widget.ads[index], _trackedIds);
              }
            },
          ),
          items: widget.ads.map((ad) {
            return GestureDetector(
              onTap: () => handleAdClick(context, ad),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: ad.photos.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(_getOptimizedImageUrl(ad.photos.first)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey.shade200,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ad.businessName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                ad.businessName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (ad.isOfficial)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade700, Colors.orange.shade600],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                ad.officialBadgeText ?? 'Trenda Official',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Sponsored',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.ads.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.ads.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentIndex == entry.key ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentIndex == entry.key
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
