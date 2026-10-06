// lib/features/home/presentation/official_collection_page.dart
// "See all" grid for a single Official Trenda Store collection (route
// /official-collection, StoreCollection passed via GoRouter `extra`). Reuses the
// shared OfficialProductCard. Read-only over the already-loaded collection products.
//
// Built as a CustomScrollView rather than Column + Expanded so the Official
// Trenda ad below the grid SCROLLS with the products instead of sitting pinned
// to the bottom of the viewport as a permanent footer.
import 'package:flutter/material.dart';
import '../providers/official_collections_provider.dart';
import '../../core/widgets/frontend_official_ad_slot.dart';
import 'widgets/official_product_card.dart';

const Color _kGoldDark = Color(0xFFB8860B);

class OfficialCollectionPage extends StatelessWidget {
  const OfficialCollectionPage({super.key, required this.collection});

  final StoreCollection collection;

  @override
  Widget build(BuildContext context) {
    final products = collection.products;
    final accent = colorFromHex(collection.accentColor, _kGoldDark);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Text(collection.title),
      ),
      body: CustomScrollView(
        slivers: [
          if ((collection.subtitle ?? '').trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text(
                  collection.subtitle!.trim(),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ),

          // Official Trenda ads — above the grid. Unsold → renders nothing.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 10, 0, 2),
              child: FrontendOfficialAdSlot(
                slotId: 'frontend.official_collection.top',
              ),
            ),
          ),

          if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('This collection is empty')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.57,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => OfficialProductCard(product: products[i]),
                  childCount: products.length,
                ),
              ),
            ),

          // Official Trenda ads — below the grid.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: FrontendOfficialAdSlot(
                slotId: 'frontend.official_collection.bottom',
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
