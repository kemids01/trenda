import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step12Review extends ConsumerWidget {
  const Step12Review({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(installmentFormProvider.select((s) => s.formData));

    final personal = data['personalInfo'] as Map<String, dynamic>? ?? {};
    final address = data['addressInfo'] as Map<String, dynamic>? ?? {};
    final income = data['incomeInfo'] as Map<String, dynamic>? ?? {};
    final housing = data['housingInfo'] as Map<String, dynamic>? ?? {};
    final spouse = data['spouseInfo'] as Map<String, dynamic>? ?? {};
    final expenses = data['expensesInfo'] as Map<String, dynamic>? ?? {};
    final dependentsData = data['dependents'] as Map<String, dynamic>? ?? {};

    final productPrice = (data['productPrice'] ?? 0).toDouble();
    final downPct = (data['downPaymentPercent'] ?? 0).toDouble();
    final downAmount = productPrice * downPct / 100;

    // Calculate total expenses
    double totalExpenses = 0;
    expenses.forEach((key, v) {
      if (v is num && key != 'totalExpenses') totalExpenses += v.toDouble();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Final Review', Icons.fact_check_outlined,
            subtitle: 'Verify all details before submitting'),

        // Photo & ID Verification
        if (personal['photoUrl'] != null || personal['validIdFrontUrl'] != null)
          _sectionCard('Verification', Icons.verified_user_outlined, [
            if (personal['photoUrl'] != null)
              Row(
                children: [
                  ClipOval(
                    child: Image.network(personal['photoUrl'],
                        width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selfie ✓',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green)),
                      if (personal['idType'] != null)
                        Text('ID: ${personal['idType']}',
                            style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            if (personal['validIdFrontUrl'] != null &&
                personal['validIdBackUrl'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(personal['validIdFrontUrl'],
                          height: 60, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(personal['validIdBackUrl'],
                          height: 60, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            ],
          ]),

        // Product Summary
        _sectionCard('Product', Icons.shopping_bag_outlined, [
          summaryRow('Price', '₱${productPrice.toStringAsFixed(2)}'),
          summaryRow('Down Payment', '₱${downAmount.toStringAsFixed(2)}'),
        ]),

        // Personal
        _sectionCard('Applicant', Icons.person_outline, [
          summaryRow(
              'Name',
              '${personal['firstName'] ?? ''} ${personal['lastName'] ?? ''}'
                  .trim()),
          if (personal['gender'] != null)
            summaryRow('Gender', personal['gender']),
          if (personal['dateOfBirth'] != null)
            summaryRow('Birthday',
                personal['dateOfBirth'].toString().split('T').first),
          summaryRow('Mobile', personal['mobileNumber'] ?? '—'),
          summaryRow('Email', personal['email'] ?? '—'),
        ]),

        // Address
        _sectionCard('Address', Icons.location_on_outlined, [
          if (address['street'] != null)
            summaryRow('Street', address['street']),
          summaryRow('Barangay', address['barangay'] ?? '—'),
          summaryRow('Municipality', address['municipality'] ?? '—'),
          summaryRow('Province', address['province'] ?? '—'),
          if (address['gpsLatitude'] != null)
            summaryRow('GPS',
                '${address['gpsLatitude']?.toStringAsFixed(4)}, ${address['gpsLongitude']?.toStringAsFixed(4)}'),
        ]),

        // Income
        _sectionCard('Employment', Icons.work_outline, [
          summaryRow('Status', income['status'] ?? '—'),
          summaryRow('Employer', income['employerName'] ?? '—'),
          summaryRow('Income', '₱${income['monthlyIncome'] ?? 0}'),
        ]),

        // Housing & Household
        _sectionCard('Housing', Icons.house_outlined, [
          summaryRow('Type', housing['type'] ?? '—'),
          summaryRow('Years', '${housing['yearsOfStay'] ?? 0}'),
          summaryRow('Dependents', '${dependentsData['count'] ?? 0}'),
        ]),

        // Expenses
        _sectionCard('Expenses', Icons.account_balance_wallet_outlined, [
          if (expenses['rent'] != null && (expenses['rent'] as num) > 0)
            summaryRow('Rent', '₱${expenses['rent']}'),
          if (expenses['electricity'] != null &&
              (expenses['electricity'] as num) > 0)
            summaryRow('Electricity', '₱${expenses['electricity']}'),
          if (expenses['water'] != null && (expenses['water'] as num) > 0)
            summaryRow('Water', '₱${expenses['water']}'),
          if (expenses['internet'] != null && (expenses['internet'] as num) > 0)
            summaryRow('Internet', '₱${expenses['internet']}'),
          summaryRow('Total Monthly', '₱${totalExpenses.toStringAsFixed(2)}',
              valueColor: Colors.red.shade600, bold: true),
        ]),

        // Spouse (if applicable)
        if (spouse['hasSpouse'] == true)
          _sectionCard('Spouse', Icons.favorite_outline, [
            summaryRow('Name', spouse['name'] ?? '—'),
            summaryRow('Employer', spouse['employer'] ?? '—'),
            summaryRow('Income', '₱${spouse['monthlyIncome'] ?? 0}'),
          ]),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Applications are subject to approval. You will be notified about your status.',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: formCard(children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        const Divider(height: 12),
        ...rows,
      ]),
    );
  }
}
