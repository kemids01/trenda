import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step04Employment extends ConsumerStatefulWidget {
  const Step04Employment({super.key});

  @override
  ConsumerState<Step04Employment> createState() => _Step04EmploymentState();
}

class _Step04EmploymentState extends ConsumerState<Step04Employment> {
  late TextEditingController _employerCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _yearsCtrl;
  String _status = 'Employed';

  @override
  void initState() {
    super.initState();
    final income = ref.read(installmentFormProvider).formData['incomeInfo']
            as Map<String, dynamic>? ??
        {};

    _employerCtrl = TextEditingController(text: income['employerName']);
    _positionCtrl = TextEditingController(text: income['position']);
    _salaryCtrl =
        TextEditingController(text: income['monthlyIncome']?.toString());
    _yearsCtrl =
        TextEditingController(text: income['yearsInService']?.toString());
    if (income['status'] != null) _status = income['status'];

    _employerCtrl
        .addListener(() => _update('employerName', _employerCtrl.text));
    _positionCtrl.addListener(() => _update('position', _positionCtrl.text));
    _salaryCtrl.addListener(
        () => _update('monthlyIncome', double.tryParse(_salaryCtrl.text) ?? 0));
    _yearsCtrl.addListener(
        () => _update('yearsInService', double.tryParse(_yearsCtrl.text) ?? 0));
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('incomeInfo', {key: value});
  }

  @override
  void dispose() {
    _employerCtrl.dispose();
    _positionCtrl.dispose();
    _salaryCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Employment & Income', Icons.work_outline,
            subtitle: 'Source of income details'),
        formCard(children: [
          DropdownButtonFormField<String>(
            value: _status,
            decoration:
                compactInput('Employment Status', icon: Icons.badge_outlined),
            isDense: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              'Employed',
              'Self-Employed',
              'Business Owner',
              'Freelancer',
              'Retired'
            ]
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _status = val);
                _update('status', val);
              }
            },
          ),
          fieldGap,
          TextFormField(
            controller: _employerCtrl,
            decoration: compactInput('Employer / Business Name',
                icon: Icons.business_outlined),
            textCapitalization: TextCapitalization.words,
          ),
          fieldGap,
          TextFormField(
            controller: _positionCtrl,
            decoration: compactInput('Position / Nature of Business'),
            textCapitalization: TextCapitalization.words,
          ),
          fieldGap,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Monthly Income', prefix: '₱ '),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _yearsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Years in Service'),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
