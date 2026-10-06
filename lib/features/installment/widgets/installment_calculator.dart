import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/models/installment_model.dart';
import 'package:go_router/go_router.dart';
import '../providers/installment_provider.dart';

class InstallmentCalculatorWidget extends ConsumerStatefulWidget {
  final ProductModel product;

  const InstallmentCalculatorWidget({super.key, required this.product});

  @override
  ConsumerState<InstallmentCalculatorWidget> createState() =>
      _InstallmentCalculatorWidgetState();
}

class _InstallmentCalculatorWidgetState
    extends ConsumerState<InstallmentCalculatorWidget> {
  InstallmentPlan? _selectedPlan;
  double _downPaymentPercent = 20.0;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync =
        ref.watch(productInstallmentPlansProvider(widget.product.id));

    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        // Initialize selected plan if null
        if (_selectedPlan == null && plans.isNotEmpty) {
          // Default to longest term for lowest monthly payment
          plans.sort((a, b) => b.durationMonths.compareTo(a.durationMonths));
          _selectedPlan = plans.first;
          _downPaymentPercent = _selectedPlan!.minDownPaymentPercent;
        }

        // Available plans sorted by duration
        final sortedPlans = List<InstallmentPlan>.from(plans)
          ..sort((a, b) => a.durationMonths.compareTo(b.durationMonths));

        // Calculate — use plan.finalPrice for both down payment and monthly
        final plan = _selectedPlan!;
        final downPaymentAmount =
            (plan.finalPrice * (_downPaymentPercent / 100));
        final monthly = plan.calculateMonthlyPayment(downPaymentAmount);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.5),
            border: Border.all(color: Colors.blue.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header (Always Visible)
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pay via Installment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            Text(
                              'As low as ₱${monthly.toStringAsFixed(2)} / month',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.blue.shade400,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Content
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),

                      // Duration Selector
                      DropdownButtonFormField<InstallmentPlan>(
                        value: _selectedPlan,
                        decoration: const InputDecoration(
                          labelText: 'Payment Terms',
                          prefixText: 'Duration: ',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: sortedPlans.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text('${p.durationMonths} Months'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPlan = val;
                              // Clamp downpayment if needed
                              if (_downPaymentPercent <
                                  val.minDownPaymentPercent) {
                                _downPaymentPercent = val.minDownPaymentPercent;
                              } else if (_downPaymentPercent >
                                  val.maxDownPaymentPercent) {
                                _downPaymentPercent = val.maxDownPaymentPercent;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Downpayment Slider
                      Text(
                        'Down Payment: ${_downPaymentPercent.toStringAsFixed(0)}% (₱${downPaymentAmount.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Slider(
                        value: _downPaymentPercent,
                        min: plan.minDownPaymentPercent,
                        max: plan.maxDownPaymentPercent,
                        divisions: (plan.maxDownPaymentPercent -
                                plan.minDownPaymentPercent)
                            .toInt(),
                        label: '${_downPaymentPercent.round()}%',
                        onChanged: (val) =>
                            setState(() => _downPaymentPercent = val),
                      ),

                      // Summary Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Down Payment',
                                '₱${downPaymentAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 4),
                            _buildSummaryRow('Monthly Amortization',
                                '₱${monthly.toStringAsFixed(2)}',
                                isBold: true),
                            const SizedBox(height: 8),
                            Text(
                              'Total w/ Interest: ₱${(monthly * plan.durationMonths + downPaymentAmount).toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            // Navigate to Wizard with selected plan & specs
                            final draftApplication = {
                              'productId': widget.product.id,
                              'planId': _selectedPlan!.id,
                              'downPaymentPercent': _downPaymentPercent,
                              'productPrice': _selectedPlan!.finalPrice,
                            };

                            context.push('/installment/apply',
                                extra: draftApplication);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Apply for this Plan'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox
          .shrink(), // Don't show anything while loading to avoid resize jump
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
