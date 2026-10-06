import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step08Expenses extends ConsumerStatefulWidget {
  const Step08Expenses({super.key});

  @override
  ConsumerState<Step08Expenses> createState() => _Step08ExpensesState();
}

class _Step08ExpensesState extends ConsumerState<Step08Expenses> {
  final Map<String, TextEditingController> _controllers = {};

  static const _expenseTypes = [
    'Food & Groceries',
    'Apartment / House Rental',
    'Electricity Bill',
    'Water Bill',
    'Internet Bill',
    'Transportation',
    'Education',
    'Loans / Debts',
    'Others',
  ];

  // Map UI labels to backend field names
  static const _fieldMap = {
    'Food & Groceries': 'food',
    'Apartment / House Rental': 'rent',
    'Electricity Bill': 'electricity',
    'Water Bill': 'water',
    'Internet Bill': 'internet',
    'Transportation': 'transportation',
    'Education': 'education',
    'Loans / Debts': 'loans',
    'Others': 'others',
  };

  @override
  void initState() {
    super.initState();
    final expenses = ref.read(installmentFormProvider).formData['expensesInfo']
            as Map<String, dynamic>? ??
        {};

    for (var type in _expenseTypes) {
      final key = _fieldMap[type] ?? type;
      _controllers[type] =
          TextEditingController(text: expenses[key]?.toString() ?? '');
      _controllers[type]!.addListener(() {
        final val = double.tryParse(_controllers[type]!.text) ?? 0;
        _update(key, val);
      });
    }
  }

  void _update(String key, double value) {
    ref.read(installmentFormProvider.notifier).updateSection(
        'expensesInfo', {key: value, 'totalExpenses': _totalExpenses});
  }

  double get _totalExpenses {
    double total = 0;
    for (var ctrl in _controllers.values) {
      total += double.tryParse(ctrl.text) ?? 0;
    }
    return total;
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Monthly Expenses', Icons.account_balance_wallet_outlined,
            subtitle: 'Estimate your average monthly spending'),
        formCard(children: [
          for (int i = 0; i < _expenseTypes.length; i++) ...[
            TextFormField(
              controller: _controllers[_expenseTypes[i]],
              keyboardType: TextInputType.number,
              decoration: compactInput(_expenseTypes[i], prefix: '₱ '),
              onChanged: (_) => setState(() {}),
            ),
            if (i < _expenseTypes.length - 1) const SizedBox(height: 8),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Monthly Expenses',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade700)),
              Text(
                '₱${_totalExpenses.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red.shade600),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
