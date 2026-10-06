// lib/features/search/presentation/visual_search_sheet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trenda_shared/models/product_model.dart';

import '../../home/presentation/widgets/shop_card_grid.dart';
import '../../home/presentation/widgets/shop_product_card.dart';
import '../providers/visual_search_provider.dart';

class VisualSearchSheet extends ConsumerStatefulWidget {
  const VisualSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VisualSearchSheet(),
    );
  }

  @override
  ConsumerState<VisualSearchSheet> createState() => _VisualSearchSheetState();
}

class _VisualSearchSheetState extends ConsumerState<VisualSearchSheet> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late final AnimationController _scanAnim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visualSearchProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );
      if (file == null) return;

      setState(() {
        _selectedImage = File(file.path);
      });

      await ref.read(visualSearchProvider.notifier).searchWithFile(_selectedImage!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final state = ref.watch(visualSearchProvider);

    final height = MediaQuery.of(context).size.height * 0.9;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF12161E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.camera_enhance_rounded, color: Color(0xFF3B82F6), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Trenda Visual Search',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _selectedImage == null
                ? _buildImagePickerPrompt(theme)
                : _buildAnalysisContent(context, theme, state),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerPrompt(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              size: 64,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Snap or Upload a Product Photo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Trenda AI will scan the item, identify what it is, and check our catalog for exact or closest matches.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: _OptionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  color: const Color(0xFF3B82F6),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OptionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'From Gallery',
                  color: dark ? const Color(0xFF2A313D) : const Color(0xFFE2E8F0),
                  textColor: dark ? Colors.white : Colors.black87,
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent(BuildContext context, ThemeData theme, VisualSearchState state) {
    return Column(
      children: [
        // Image Preview Header with Scanning Animation
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_selectedImage!, fit: BoxFit.cover),
                if (state.isLoading) ...[
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment(0, (_scanAnim.value * 2) - 1),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.9),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Trenda AI identifying product...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      tooltip: 'Change photo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Results Section
        Expanded(
          child: Builder(builder: (context) {
            if (state.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing photo details & scanning stores...',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            if (state.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(visualSearchProvider.notifier).searchWithFile(_selectedImage!),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final result = state.result;
            if (result == null) return const SizedBox.shrink();

            final id = result.identification;
            final hasExact = result.exactMatches.isNotEmpty;
            final hasSimilar = result.similarProducts.isNotEmpty;

            return CustomScrollView(
              slivers: [
                // Identification Card Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3B82F6), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI Identification: ${id.productTitle.isNotEmpty ? id.productTitle : "Product Detected"}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (id.visualSummary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              id.visualSummary,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (id.category.isNotEmpty) _TagChip(label: id.category, icon: Icons.category_rounded),
                              if (id.brand.isNotEmpty && id.brand.toLowerCase() != 'unknown')
                                _TagChip(label: id.brand, icon: Icons.branding_watermark_rounded),
                              if (id.primaryColor.isNotEmpty)
                                _TagChip(label: id.primaryColor, icon: Icons.palette_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Exact Matches Section
                if (hasExact) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Exact Product Matches',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildProductGrid(result.exactMatches),
                ],

                // Similar Products Section
                if (hasSimilar) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            hasExact ? Icons.grid_view_rounded : Icons.search_rounded,
                            color: const Color(0xFF3B82F6),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasExact ? 'Similar Products on Trenda' : 'Closest Matching Products',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildProductGrid(result.similarProducts),
                ],

                // Empty State
                if (!hasExact && !hasSimilar) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching products found in stock',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We identified "${id.productTitle}", but no Trenda seller currently lists this item.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverGrid(
        gridDelegate: const ShopCardGridDelegate(),
        delegate: SliverChildBuilderDelegate(
          (context, i) => ShopProductCard(
            product: products[i],
            onTap: () {
              Navigator.of(context).pop();
              context.push('/product/${products[i].id}');
            },
          ),
          childCount: products.length,
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 28, color: iconColor ?? textColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TagChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }
}
