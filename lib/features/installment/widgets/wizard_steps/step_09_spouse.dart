import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step09Spouse extends ConsumerStatefulWidget {
  const Step09Spouse({super.key});

  @override
  ConsumerState<Step09Spouse> createState() => _Step09SpouseState();
}

class _Step09SpouseState extends ConsumerState<Step09Spouse> {
  bool _hasSpouse = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _employerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final spouse = ref.read(installmentFormProvider).formData['spouseInfo']
            as Map<String, dynamic>? ??
        {};

    _hasSpouse = spouse['hasSpouse'] ?? false;
    _nameCtrl.text = spouse['name'] ?? '';
    _incomeCtrl.text = spouse['monthlyIncome']?.toString() ?? '';
    _employerCtrl.text = spouse['employer'] ?? '';

    _nameCtrl.addListener(() => _update('name', _nameCtrl.text));
    _employerCtrl.addListener(() => _update('employer', _employerCtrl.text));
    _incomeCtrl.addListener(
        () => _update('monthlyIncome', double.tryParse(_incomeCtrl.text) ?? 0));
  }

  void _update(String key, dynamic value) {
    if (!_hasSpouse && key != 'hasSpouse') return;
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('spouseInfo', {key: value});
  }

  void _toggleSpouse(bool? value) {
    setState(() => _hasSpouse = value ?? false);
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('spouseInfo', {'hasSpouse': _hasSpouse});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    _employerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Spouse Information', Icons.favorite_outline,
            subtitle: 'Optional — if married'),
        formCard(children: [
          SwitchListTile.adaptive(
            value: _hasSpouse,
            onChanged: _toggleSpouse,
            title: const Text('I am married / have a spouse',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (_hasSpouse) ...[
            const Divider(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  compactInput('Spouse Full Name', icon: Icons.person_outline),
              textCapitalization: TextCapitalization.words,
            ),
            fieldGap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _employerCtrl,
                    decoration: compactInput('Employer / Business'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _incomeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: compactInput('Monthly Income', prefix: '₱ '),
                  ),
                ),
              ],
            ),
          ],
        ]),
      ],
    );
  }
}
