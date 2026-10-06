// lib/features/home/presentation/widgets/shop_quick_lanes.dart
// The Shop tab's swipeable row of lane buttons, with a small scroll indicator
// underneath so the row reads as a carousel: a short track whose thumb shows
// how much of the row is visible and where you are in it.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/shop_category_lanes.dart';

class ShopQuickLanes extends StatefulWidget {
  const ShopQuickLanes({super.key});

  @override
  State<ShopQuickLanes> createState() => _ShopQuickLanesState();
}

// Stateful only to own the notifier's lifecycle; the indicator repaints from
// the notifier (ValueListenableBuilder), never setState.
class _ShopQuickLanesState extends State<ShopQuickLanes> {
  // Fed by scroll AND metrics notifications: a ScrollController does not
  // notify on first layout, so listening to it alone leaves the indicator
  // blank until the first swipe.
  final _metrics = ValueNotifier<ScrollMetrics?>(null);

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  bool _onScroll(Notification n) {
    if (n is ScrollMetricsNotification) _metrics.value = n.metrics;
    if (n is ScrollNotification) _metrics.value = n.metrics;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lanes = shopLanes();
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 76,
          child: NotificationListener<Notification>(
            onNotification: _onScroll,
            child: ListView.builder(
              key: const ValueKey('shop-quick-lanes'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              itemCount: lanes.length,
              itemBuilder: (context, i) {
                final lane = lanes[i];
                return SizedBox(
                  width: 64,
                  child: InkWell(
                    onTap: () => context.push(lane.route),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: lane.color.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                Icon(lane.icon, size: 18, color: lane.color),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            lane.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<ScrollMetrics?>(
          valueListenable: _metrics,
          builder: (context, m, _) => LaneScrollIndicator(metrics: m),
        ),
      ],
    );
  }
}

/// A short rounded track with a thumb sized to the visible share of the row
/// and positioned by the scroll offset. Keeps its 4px of height but draws
/// nothing until the row has laid out, or when every button already fits.
class LaneScrollIndicator extends StatelessWidget {
  const LaneScrollIndicator({
    super.key,
    required this.metrics,
    this.trackWidth = 40,
  });

  final ScrollMetrics? metrics;
  final double trackWidth;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (m == null || !m.hasContentDimensions || m.maxScrollExtent <= 0) {
      return const SizedBox(height: 4);
    }
    final scheme = Theme.of(context).colorScheme;
    final content = m.maxScrollExtent + m.viewportDimension;
    final visible = (m.viewportDimension / content).clamp(0.15, 1.0);
    final thumb = trackWidth * visible;
    final progress = (m.pixels / m.maxScrollExtent).clamp(0.0, 1.0);
    return SizedBox(
      key: const ValueKey('shop-quick-lanes-indicator'),
      width: trackWidth,
      height: 4,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            left: (trackWidth - thumb) * progress,
            top: 0,
            bottom: 0,
            width: thumb,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
