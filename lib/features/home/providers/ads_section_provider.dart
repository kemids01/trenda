// lib/features/home/providers/ads_section_provider.dart
// The Shop tab's "Ads & Services" section: two carousels of SOLD placements,
// configured in the admin app (📢 ADVERTISING ▸ Ad Placements).
//
// Every ad here was paid for, so parsing is deliberately forgiving: one bad slot
// entry drops out rather than taking the whole section — and the section down is
// every advertiser's impressions gone, not just one.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/ad_model.dart';
import '../../core/providers/municipality_provider.dart';

String? _nonEmpty(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// One carousel: an optional Featured ad plus the sold slots, in slot order
/// (the server already ordered them; gaps for unsold slots are expected).
class AdsCarousel {
  final AdModel? featured;
  final List<AdModel> top10;

  const AdsCarousel({this.featured, required this.top10});

  bool get isEmpty => featured == null && top10.isEmpty;

  /// Every ad to show, Featured first — the order the carousel renders.
  List<AdModel> get all => [if (featured != null) featured!, ...top10];

  factory AdsCarousel.fromJson(Object? json) {
    if (json is! Map) return const AdsCarousel(top10: []);

    final rawTop = json['top10'];
    final top = (rawTop is List)
        ? rawTop
            .whereType<Map>()
            .map((e) => e['ad'])
            .whereType<Map<String, dynamic>>()
            .map(AdModel.fromJson)
            .toList()
        : <AdModel>[];

    final f = json['featured'];
    return AdsCarousel(
      featured: f is Map<String, dynamic> ? AdModel.fromJson(f) : null,
      top10: top,
    );
  }
}

class AdsSection {
  final String title;
  final String vendorLabel;
  final String servicesLabel;

  /// Hex (`#RRGGBB`) for the band behind the carousels; null → page surface.
  final String? backgroundColor;

  /// Hex for the heading tint; null → the app's primary colour.
  final String? accentColor;

  final AdsCarousel vendor;
  final AdsCarousel services;

  const AdsSection({
    required this.title,
    required this.vendorLabel,
    required this.servicesLabel,
    this.backgroundColor,
    this.accentColor,
    required this.vendor,
    required this.services,
  });

  bool get isEmpty => vendor.isEmpty && services.isEmpty;

  factory AdsSection.fromJson(Map<String, dynamic> json) {
    final config = json['config'];
    String cfg(String key, String fallback) =>
        (config is Map ? _nonEmpty(config[key]) : null) ?? fallback;

    return AdsSection(
      title: cfg('title', 'Ads & Services'),
      vendorLabel: cfg('vendorLabel', 'Top 10 Vendor Ads'),
      servicesLabel: cfg('servicesLabel', 'Top 10 Services'),
      backgroundColor:
          config is Map ? _nonEmpty(config['backgroundColor']) : null,
      accentColor: config is Map ? _nonEmpty(config['accentColor']) : null,
      vendor: AdsCarousel.fromJson(json['vendor']),
      services: AdsCarousel.fromJson(json['services']),
    );
  }
}

/// `GET /api/ads-section?municipality=`.
///
/// Fails soft to null — a backend hiccup costs the section, not the Shop tab —
/// and returns null for an entirely empty section so the band is not built at
/// all rather than rendering a coloured strip with nothing in it.
final adsSectionProvider = FutureProvider<AdsSection?>((ref) async {
  final municipality = ref.watch(municipalityProvider);

  try {
    final params = <String, String>{
      if (municipality != null) 'municipality': municipality,
    };
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/ads-section')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['success'] != true) return null;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;

    // An empty section is still returned: the band renders its two columns as
    // "Coming soon", which advertises the inventory rather than hiding that it
    // exists. Only a failed/malformed response yields null and no band at all.
    return AdsSection.fromJson(data);
  } catch (_) {
    return null;
  }
});
