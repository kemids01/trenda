import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/data/ads_repository.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Signature for the analytics side-effect fired when an ad is clicked.
typedef AdClickTracker = void Function(String adId);

void _defaultAdClickTracker(String adId) {
  // Fire-and-forget; the repository swallows its own errors.
  AdsRepository(baseUrl: AppConfig.backendBaseUrl).trackAdClick(adId);
}

/// Records a click for [ad] via [tracker] (default = real backend tracking).
/// Pure/testable: no navigation, no context. Skips ads with an empty id.
void recordAdClick(AdModel ad, {AdClickTracker? tracker}) {
  final id = ad.id;
  if (id.isEmpty) return;
  (tracker ?? _defaultAdClickTracker)(id);
}

/// Signature for the analytics side-effect fired when an ad is viewed (impression).
typedef AdViewTracker = void Function(String adId);

void _defaultAdViewTracker(String adId) {
  AdsRepository(baseUrl: AppConfig.backendBaseUrl).trackAdView(adId);
}

/// Returns true (and records [id] in [seen]) the first time an id is seen; false afterwards.
/// Empty ids are never tracked. Pure — used to dedupe carousel impressions.
bool shouldTrackImpression(Set<String> seen, String id) {
  if (id.isEmpty) return false;
  return seen.add(id); // Set.add returns false when the id was already present
}

/// Records one impression for [ad] via [tracker] (default = real backend tracking),
/// deduped against [seen] so each ad counts at most once per session/widget lifetime.
void recordAdImpression(AdModel ad, Set<String> seen, {AdViewTracker? tracker}) {
  if (shouldTrackImpression(seen, ad.id)) {
    (tracker ?? _defaultAdViewTracker)(ad.id);
  }
}

/// Handles ad clicks by routing to the configured destination
Future<void> handleAdClick(BuildContext context, AdModel ad) async {
  recordAdClick(ad); // fire analytics before navigation
  final action = ad.action;

  // Navigate based on action type
  if (action != null) {
    final type = action['type'];

    if (type == 'store') {
      // Navigate to Vendor Store
      context.push('/store/${ad.ownerId}');
    } else if (type == 'product') {
      // Navigate to Specific Product
      final targetId = action['targetId'];
      if (targetId != null) {
        context.push('/product/$targetId');
      }
    } else if (type == 'url') {
      // Determine URL
      final url = action['url'];
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          debugPrint('Could not launch URL: $url');
        }
      }
    }
  } else {
    // Default fallback: Go to Ad Details
    context.push('/ad-details', extra: ad);
  }
}
