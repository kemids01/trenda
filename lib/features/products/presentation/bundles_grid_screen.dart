import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/bundle_model.dart';
import '../providers/bundles_provider.dart';

class BundlesGridScreen extends ConsumerStatefulWidget {
  const BundlesGridScreen({super.key});

  @override
  ConsumerState<BundlesGridScreen> createState() => _BundlesGridScreenState();
}

class _BundlesGridScreenState extends ConsumerState<BundlesGridScreen> {
  @override
  Widget build(BuildContext context) {
    final bundlesAsync = ref.watch(publicBundlesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with search
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.purple.shade600,
            elevation: 0,
            expandedHeight: 90,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(56, 45, 12, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade700, Colors.purple.shade500],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: Colors.grey.shade500, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search bundles...',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                          // A sort menu sat here with a single option that was
                          // stored and never applied — removed rather than fake.
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            title: const Text('Bundle Deals',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // Bundles Grid
          bundlesAsync.when(
            data: (bundles) => _buildGrid(bundles),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<ProductBundle> bundles) {
    if (bundles.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No bundles found')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.57,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _BundleGridCard(bundle: bundles[index]),
          childCount: bundles.length,
        ),
      ),
    );
  }
}

class _BundleGridCard extends StatelessWidget {
  final ProductBundle bundle;
  const _BundleGridCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/bundles/${bundle.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: bundle.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.shade100),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image),
                      ),
                    ),
                    if (bundle.discountPercent > 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SAVE ₱${bundle.savings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      color: Colors.purple.shade50,
                      child: Text('BUNDLE',
                          style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.bold))),
                  const SizedBox(height: 4),
                  Text(
                    bundle.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₱${bundle.bundlePrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              '₱${bundle.originalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          ]),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.add_shopping_cart,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
