// lib/features/home/presentation/category_screen.dart
// The Shop tab's quick lanes that are not product grids: Shops, Ads, Services.
//
// "All items" and "On sale" are ProductBrowsePage and are routed directly —
// they carry their own app bar, filters and curated carousel, so wrapping them
// in this screen's bar would give them two.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/ads/providers/ads_provider.dart'
    show AdKind;
import 'stores_tab.dart';
import 'ads_tab.dart';
import '../../ads/utils/ad_click_handler.dart';

class CategoryScreen extends StatelessWidget {
  final String category;

  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    // Category display info
    final Map<String, Map<String, dynamic>> categoryInfo = {
      'ads': {
        'title': 'Ads',
        'description': 'Browse featured ads from vendors',
        'icon': Icons.campaign,
        'color': const Color(0xFFB4831F),
      },
      'stores': {
        'title': 'Stores',
        'description': 'Explore local stores near you',
        'icon': Icons.store,
        // Deep shopfront green — sits with the awning palette on the stores
        // street instead of fighting it the way flat Colors.green did.
        'color': const Color(0xFF14532D),
      },
      'services': {
        'title': 'Services',
        'description': 'Find professional services',
        'icon': Icons.handyman_rounded,
        'color': const Color(0xFF6B3A6E),
      },
    };

    final info = categoryInfo[category];

    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Category')),
        body: const Center(child: Text('Category not found')),
      );
    }

    // Ads and Services are the SAME list widget scoped to a different
    // `Ad.kind`: same cards, same search, same impression tracking. A second
    // page would be a second place for either to break.
    final Widget body;
    switch (category) {
      case 'stores':
        body = const StoresTab();
      case 'services':
        body = AdsTab(
          kind: AdKind.service,
          onAdTap: (ad) => handleAdClick(context, ad),
        );
      default:
        body = AdsTab(
          kind: AdKind.vendor,
          onAdTap: (ad) => handleAdClick(context, ad),
        );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: info['color'] as Color,
        foregroundColor: Colors.white,
        title: Text(info['title'] as String),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}
