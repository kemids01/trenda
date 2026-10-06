import 'package:flutter/material.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../../utils/product_specs.dart';

/// Storefront "Specifications" card for listings that carry template spec fields
/// (big-ticket: model/year/features; service: coverage/duration). Renders
/// nothing when the listing has no populated specs.
class ProductSpecsSection extends StatelessWidget {
  final ProductModel product;

  const ProductSpecsSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final rows = specRows(resolveTemplate(product.category), product.attributes);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Specifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        r.key,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.value,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
