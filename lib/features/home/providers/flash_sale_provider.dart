// lib/features/home/providers/flash_sale_provider.dart
// The Shop tab's ⚡ Flash Sale band — `GET /api/flash-sales/live?municipality=`
// (trenda_backend controllers/flashSalePublicController.js).
//
// The flash PRICE shown here is display only: the server re-prices every cart
// line and the checkout against the same live sale (services/flashSalePricing.js),
// so a stale screen can never charge the wrong amount — it can only be refused.
//
// Fails soft: any error → no band, never an error box where a deal should be.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';

import '../../core/providers/municipality_provider.dart';
import '../utils/flash_sale_logic.dart' show FlashPalette;

class FlashItem {
  final String itemId;
  final String productId;
  final String name;
  final String? image;
  final bool isOfficial;
  final String seller;
  final String sellerArea;
  final double regularPrice;
  final double flashPrice;
  final int discountPercent;
  final int flashStock;
  final int soldCount;
  final int stockLeft;
  final int soldPercent;
  final int perCustomerLimit;

  const FlashItem({
    required this.itemId,
    required this.productId,
    required this.name,
    this.image,
    this.isOfficial = false,
    this.seller = '',
    this.sellerArea = '',
    required this.regularPrice,
    required this.flashPrice,
    this.discountPercent = 0,
    this.flashStock = 0,
    this.soldCount = 0,
    this.stockLeft = 0,
    this.soldPercent = 0,
    this.perCustomerLimit = 0,
  });

  bool get soldOut => stockLeft <= 0;

  factory FlashItem.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return FlashItem(
      itemId: '${j['itemId'] ?? ''}',
      productId: '${j['productId'] ?? ''}',
      name: '${j['name'] ?? ''}',
      image: j['image']?.toString(),
      isOfficial: j['isOfficial'] == true,
      seller: '${j['seller'] ?? ''}',
      sellerArea: '${j['sellerArea'] ?? ''}',
      regularPrice: d(j['regularPrice']),
      flashPrice: d(j['flashPrice']),
      discountPercent: i(j['discountPercent']),
      flashStock: i(j['flashStock']),
      soldCount: i(j['soldCount']),
      stockLeft: i(j['stockLeft']),
      soldPercent: i(j['soldPercent']),
      perCustomerLimit: i(j['perCustomerLimit']),
    );
  }
}

class FlashSale {
  final String id;
  final String title;
  final String subtitle;
  final DateTime startsAt;

  /// The end, already corrected to THIS device's clock (see [FlashSaleFeed.skew]).
  final DateTime endsAt;
  final List<FlashItem> items;

  /// The band's colours, set per campaign in admin (defaults when unset).
  final FlashPalette palette;

  const FlashSale({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.startsAt,
    required this.endsAt,
    required this.items,
    this.palette = FlashPalette.fallback,
  });
}

class FlashSaleFeed {
  final List<FlashSale> sales;

  /// The next sale to start, when nothing is live (the band counts down to it).
  final FlashSale? upcoming;

  const FlashSaleFeed({this.sales = const [], this.upcoming});

  /// The sale the band shows: the one ending soonest (the server sorts that way).
  FlashSale? get featured => sales.isEmpty ? null : sales.first;

  bool get isEmpty => sales.isEmpty && upcoming == null;

  /// Every live item across every live sale, for the See-all page.
  List<FlashItem> get allItems => [for (final s in sales) ...s.items];

  /// The live deal on [productId], if any — product detail reads this.
  ({FlashSale sale, FlashItem item})? dealFor(String productId) {
    for (final s in sales) {
      for (final i in s.items) {
        if (i.productId == productId) return (sale: s, item: i);
      }
    }
    return null;
  }

  /// Parse the payload. Times are shifted by the server↔device clock difference,
  /// so a phone whose clock is 3 minutes off still ends the countdown on time.
  factory FlashSaleFeed.fromJson(Map<String, dynamic> data, {DateTime? receivedAt}) {
    final serverNow = DateTime.tryParse('${data['serverTime']}');
    final skew = serverNow == null ? Duration.zero : (receivedAt ?? DateTime.now()).difference(serverNow);
    DateTime t(dynamic v) => (DateTime.tryParse('$v') ?? DateTime.now()).toLocal().add(skew);
    FlashSale sale(Map<String, dynamic> s) => FlashSale(
          id: '${s['id'] ?? ''}',
          title: '${s['title'] ?? 'Flash Sale'}',
          subtitle: '${s['subtitle'] ?? ''}',
          startsAt: t(s['startsAt']),
          endsAt: t(s['endsAt']),
          items: ((s['items'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => FlashItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          palette: FlashPalette.fromJson(s['theme']),
        );
    return FlashSaleFeed(
      sales: ((data['sales'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => sale(Map<String, dynamic>.from(e)))
          .where((s) => s.items.isNotEmpty)
          .toList(),
      upcoming: data['upcoming'] is Map ? sale(Map<String, dynamic>.from(data['upcoming'])) : null,
    );
  }
}

final flashSaleFeedProvider = FutureProvider<FlashSaleFeed>((ref) async {
  final municipality = ref.watch(municipalityProvider);
  try {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/flash-sales/live').replace(
      queryParameters: {if (municipality != null && municipality.isNotEmpty) 'municipality': municipality},
    );
    final res = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.connectTimeout);
    if (res.statusCode != 200) return const FlashSaleFeed();
    final body = jsonDecode(res.body);
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return const FlashSaleFeed();
    return FlashSaleFeed.fromJson(Map<String, dynamic>.from(data), receivedAt: DateTime.now());
  } catch (_) {
    return const FlashSaleFeed();
  }
});
