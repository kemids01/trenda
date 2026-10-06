import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../stores/utils/storefront_style.dart';
import '../../core/widgets/municipality_switcher.dart';
import '../../core/providers/municipality_provider.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'All';
  int _currentCarouselIndex = 0;

  final List<String> _categories = [
    'All',
    'Electronics',
    'Fashion',
    'Home & Garden',
    'Beauty',
    'Sports',
    'Toys',
    'Automotive'
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(publicProductsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate the products provider to trigger a refresh
          ref.invalidate(publicProductsProvider);
          // Wait a bit for the refresh to complete
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildFeaturedCarousel(),
            ),
            // RecentlyViewedSection removed
            _buildPinnedCategoryFilter(),
            productsAsync.when(
              data: (products) => _buildProductGrid(products),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isBrowsingOther = ref.watch(isBrowsingOtherMunicipalityProvider);

    return AppBar(
      backgroundColor: Colors.blue.shade600,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: const MunicipalitySwitcher(),
      ),
      leadingWidth: 180,
      title: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Search products...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
      centerTitle: true,
      bottom: isBrowsingOther
          ? PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.amber.shade700,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.explore, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Browsing only — ordering restricted to your home area',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFeaturedCarousel() {
    final List<String> bannerImages = [
      'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?q=80&w=2070&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?q=80&w=2070&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=2070&auto=format&fit=crop',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // Reduced padding
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 140.0, // Reduced height
              autoPlay: true, // Autoplay enabled
              enlargeCenterPage: false,
              viewportFraction: 1.0,
              aspectRatio: 16 / 9,
              enableInfiniteScroll: true,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
            ),
            items: bannerImages.map((imageUrl) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.bottomLeft,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summer Sale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Up to 50% off on selected items',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: bannerImages.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                        alpha: _currentCarouselIndex == entry.key ? 0.9 : 0.4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedCategoryFilter() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverCategoryDelegate(
        categories: _categories,
        selectedCategory: _selectedCategory,
        onCategorySelected: (category) {
          setState(() {
            _selectedCategory = category;
            _scrollController.animateTo(
              0, // Optional: scroll to top when filter changes? Or stay.
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
      ),
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    if (products.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No products available')),
      );
    }

    // Apply filters
    var filteredProducts = products;
    if (_selectedCategory != 'All') {
      filteredProducts = filteredProducts
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    if (filteredProducts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No products match your filters')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(8), // Reduced padding
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8, // Reduced spacing
          crossAxisSpacing: 8, // Reduced spacing
          childAspectRatio: 0.57,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = filteredProducts[index];
            return ProductCard(product: product);
          },
          childCount: filteredProducts.length,
        ),
      ),
    );
  }
}

class _SliverCategoryDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  _SliverCategoryDelegate({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50], // Match background
      height: 60,
      alignment: Alignment.center,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          return FilterChip(
            label: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onCategorySelected(category),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF2196F3),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: isSelected ? 2 : 0,
            shadowColor: Colors.black26,
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(_SliverCategoryDelegate oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.categories != categories;
  }
}

/// The Search results and Products tab card: square-cornered, the price in
/// green with the star rating and units sold under it, the store name over the
/// photo's top-right and the wishlist heart at its bottom-right.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final discount = product.discountPercentage;
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 28, color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isEmpty
                      ? plate
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => plate,
                          errorWidget: (_, __, ___) => plate,
                        ),
                  if (discount > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        color: const Color(0xFFE53935),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  StoreNameCorner(
                    storeName: product.storeName,
                    house: awningPaletteFor(
                      product.vendorId.isNotEmpty ? product.vendorId : product.id,
                      brightness: theme.brightness,
                    ).stripe,
                  ),
                  // Heart in the bottom-right: the top-right is the shop's.
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Material(
                      color: scheme.surface.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(child: WishlistButton(product: product)),
                      ),
                    ),
                  ),
                  if (product.isOutOfStock)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.25,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Price in green, then the star rating and units sold.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '₱${product.basePrice.toStringAsFixed(2)}'
                          '${pricingUnitSuffix(product.pricingUnit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            color: productPriceColor(context),
                          ),
                        ),
                      ),
                      if (discount > 0 && product.compareAtPrice != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '₱${product.compareAtPrice!.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 10.5,
                              color: scheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  RatingSoldRow(
                    rating: product.averageRating,
                    reviews: product.totalReviews,
                    sold: product.sales,
                    fontSize: 10.5,
                  ),
                  if (showsStockCount(product)) ...[
                    const SizedBox(height: 2),
                    StockCountLine(
                      stock: product.stock,
                      lowThreshold: product.lowStockThreshold,
                      fontSize: 10.5,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
