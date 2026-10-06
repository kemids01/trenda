import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step01Details extends ConsumerWidget {
  const Step01Details({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formData =
        ref.watch(installmentFormProvider.select((s) => s.formData));

    final productPrice = (formData['productPrice'] ?? 0).toDouble();
    final downPct = (formData['downPaymentPercent'] ?? 0).toDouble();
    final downAmount = productPrice * (downPct / 100);
    final financed = productPrice - downAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Application Summary', Icons.receipt_long_outlined,
            subtitle: 'Review before proceeding'),
        formCard(children: [
          summaryRow('Product Price', '₱${productPrice.toStringAsFixed(2)}'),
          const Divider(height: 16),
          summaryRow('Down Payment', '₱${downAmount.toStringAsFixed(2)}',
              valueColor: Colors.orange.shade700),
          summaryRow('Down Payment %', '${downPct.toStringAsFixed(0)}%'),
          const Divider(height: 16),
          summaryRow('Amount Financed', '₱${financed.toStringAsFixed(2)}',
              valueColor: Colors.blue.shade700, bold: true),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review details above, then tap Next to fill in your application.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
