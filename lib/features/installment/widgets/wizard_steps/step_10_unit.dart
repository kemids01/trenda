import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step10Unit extends ConsumerWidget {
  const Step10Unit({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(installmentFormProvider.select((s) => s.formData));

    final productName = data['productName'] ?? 'Selected Product';
    final productPrice = (data['productPrice'] ?? 0).toDouble();
    final downPct = (data['downPaymentPercent'] ?? 0).toDouble();
    final downAmount = productPrice * downPct / 100;
    final financed = productPrice - downAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Unit & Delivery', Icons.inventory_2_outlined,
            subtitle: 'Product and delivery summary'),
        formCard(children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_bag_outlined,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
          const Divider(height: 20),
          summaryRow('Unit Price', '₱${productPrice.toStringAsFixed(2)}'),
          summaryRow('Down Payment (${downPct.toStringAsFixed(0)}%)',
              '₱${downAmount.toStringAsFixed(2)}',
              valueColor: Colors.orange.shade700),
          summaryRow('Financed Amount', '₱${financed.toStringAsFixed(2)}',
              valueColor: Colors.blue.shade700, bold: true),
        ]),
        const SizedBox(height: 10),
        formCard(children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Item will be delivered to your registered address upon approval.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
