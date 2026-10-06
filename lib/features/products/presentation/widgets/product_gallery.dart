// lib/features/products/presentation/widgets/product_gallery.dart
// The item on the counter: a swipeable gallery with a counter pill, a thumbnail
// filmstrip, and tap-to-zoom. Replaces a bare PageView whose "no image" case
// pointed at via.placeholder.com — an external host that the app has no reason
// to depend on and that simply hangs when unreachable.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductGallery extends StatefulWidget {
  final List<String> images;

  /// The seller's house colour — ties the item back to the shop it came from.
  final Color accent;
  final String heroTag;

  const ProductGallery({
    super.key,
    required this.images,
    required this.accent,
    required this.heroTag,
  });

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _images =>
      widget.images.where((i) => i.trim().isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final images = _images;

    if (images.isEmpty) {
      return _EmptyPlate(accent: widget.accent);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: images.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => _openViewer(context, images, i),
            child: CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => _Plate(accent: widget.accent),
              errorWidget: (_, __, ___) => _Plate(
                accent: widget.accent,
                icon: Icons.image_not_supported_outlined,
              ),
            ),
          ),
        ),

        // Scrim under the app bar so the back/action buttons stay readable on a
        // bright product photo.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.38),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42],
              ),
            ),
          ),
        ),

        if (images.length > 1) ...[
          Positioned(
            right: 12,
            bottom: 12,
            child: _CounterPill(current: _index + 1, total: images.length),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _Filmstrip(
              images: images,
              index: _index,
              accent: widget.accent,
              onTap: (i) {
                _controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
        ] else
          Positioned(
            right: 12,
            bottom: 12,
            child: _HintPill(
              icon: Icons.zoom_in_rounded,
              label: 'Tap to zoom',
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<String> images, int start) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _GalleryViewer(images: images, initialIndex: start),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/// Full-screen, pinch-zoomable view of the photos.
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _GalleryViewer({required this.images, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.images.length,
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white38,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _CounterPill(
                    current: _index + 1,
                    total: widget.images.length,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filmstrip extends StatelessWidget {
  final List<String> images;
  final int index;
  final Color accent;
  final ValueChanged<int> onTap;

  const _Filmstrip({
    required this.images,
    required this.index,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shown = images.length > 5 ? 5 : images.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: i == index ? accent : Colors.white54,
                  width: i == index ? 2.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 5,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: images[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black26),
                errorWidget: (_, __, ___) => Container(color: Colors.black26),
              ),
            ),
          ),
      ],
    );
  }
}

class _CounterPill extends StatelessWidget {
  final int current;
  final int total;

  const _CounterPill({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$current / $total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A painted stand-in when a photo is loading or broken.
class _Plate extends StatelessWidget {
  final Color accent;
  final IconData icon;

  const _Plate({required this.accent, this.icon = Icons.image_outlined});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, dark ? Colors.black : Colors.white, 0.88)!,
            Color.lerp(accent, dark ? Colors.black : Colors.white, 0.96)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 44, color: accent.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _EmptyPlate extends StatelessWidget {
  final Color accent;

  const _EmptyPlate({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _Plate(accent: accent),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'No photo yet',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
