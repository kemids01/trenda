import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/trenda_shared.dart';
import 'package:trenda_frontend/features/core/providers/municipality_provider.dart';

/// Official-ad slot for the consumer app that scopes municipality-targeted ads to
/// the shopper's selected browsing municipality.
///
/// The shared [OfficialAdSlot] reads the process-global [officialAdMunicipality]
/// exactly once (in its `initState`) and never refetches. The browsing
/// municipality loads asynchronously from SharedPreferences ([municipalityProvider]
/// starts null, then resolves), so a slot mounted on the first frame (e.g. the home
/// hero) would fetch WITHOUT a municipality and silently drop municipality-targeted
/// ads. We (a) keep [officialAdMunicipality] in sync with the selection and (b) key
/// the slot by that municipality — when it resolves (null → "Tuguegarao City") or
/// the user switches areas, the key changes, the shared slot remounts, and its load
/// re-runs with the correct municipality. A genuinely-null selection still mounts
/// (keyed 'none') and shows untargeted ads.
class FrontendOfficialAdSlot extends ConsumerWidget {
  final String slotId;
  final double? height;
  final bool fullBleed;

  /// Shown while the slot has no live ad (see OfficialAdSlot.whenEmpty).
  final Widget? whenEmpty;
  const FrontendOfficialAdSlot(
      {super.key,
      required this.slotId,
      this.height,
      this.fullBleed = false,
      this.whenEmpty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muni = ref.watch(municipalityProvider);
    if (muni != null && muni.trim().isNotEmpty) {
      officialAdMunicipality = muni;
    }
    return OfficialAdSlot(
      key: ValueKey('official-$slotId-${muni ?? 'none'}'),
      slotId: slotId,
      height: height,
      fullBleed: fullBleed,
      whenEmpty: whenEmpty,
    );
  }
}
