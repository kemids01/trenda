// "See location" — the one place an ad's pin becomes a map.
//
// Every app that can open an ad renders this: the shared OfficialAdDetailScreen (so
// customer, vendor and supplier get it from one edit), plus the customer app's
// /ad-details and /ad-showcase. One widget means one URL format and one failure
// message; three hand-rolled buttons would drift.
//
// It opens Google Maps externally rather than embedding a map: trenda_shared has no
// map dependency, an embedded map would need a Google key this project deliberately
// leaves unset, and the external app gives the shopper directions for free.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/map_pin.dart';

class MapPinButton extends StatelessWidget {
  /// The ad's pin. Null is the ordinary case — most ads have none — and renders
  /// nothing, so every call site can place this unconditionally.
  final MapPin? location;

  /// Compact dark pill for use over a full-bleed creative (the showcase pager).
  /// The default is a full-width button for a light card.
  final bool compact;

  const MapPinButton({super.key, required this.location, this.compact = false});

  Future<void> _open(BuildContext context) async {
    final loc = location;
    if (loc == null) return;

    final uri = Uri.parse(loc.mapsUrl);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open Maps on this device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = location;
    if (loc == null) return const SizedBox.shrink();

    if (compact) {
      return Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    loc.buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.place_outlined, size: 18),
        label: Text(
          loc.buttonLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
