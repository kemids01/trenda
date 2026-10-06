import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step05Housing extends ConsumerStatefulWidget {
  const Step05Housing({super.key});

  @override
  ConsumerState<Step05Housing> createState() => _Step05HousingState();
}

class _Step05HousingState extends ConsumerState<Step05Housing> {
  String _residenceType = 'Owned House';
  final TextEditingController _rentCtrl = TextEditingController();
  final TextEditingController _yearsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final housing = ref.read(installmentFormProvider).formData['housingInfo']
            as Map<String, dynamic>? ??
        {};

    if (housing['type'] != null) _residenceType = housing['type'];
    _rentCtrl.text = housing['rentAmount']?.toString() ?? '';
    _yearsCtrl.text = housing['yearsOfStay']?.toString() ?? '';

    _rentCtrl.addListener(
        () => _update('rentAmount', double.tryParse(_rentCtrl.text) ?? 0));
    _yearsCtrl.addListener(
        () => _update('yearsOfStay', double.tryParse(_yearsCtrl.text) ?? 0));
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('housingInfo', {key: value, 'type': _residenceType});
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Housing Information', Icons.house_outlined,
            subtitle: 'Your current living situation'),
        formCard(children: [
          DropdownButtonFormField<String>(
            value: _residenceType,
            decoration:
                compactInput('Type of Residence', icon: Icons.roofing_outlined),
            isDense: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              'Owned House',
              'Rented House',
              'Rented Apartment',
              'Living with Parents',
              'Mortgaged'
            ]
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _residenceType = val);
                _update('type', val);
              }
            },
          ),
          fieldGap,
          Row(
            children: [
              if (_residenceType.contains('Rented'))
                Expanded(
                  child: TextFormField(
                    controller: _rentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: compactInput('Monthly Rent', prefix: '₱ '),
                  ),
                ),
              if (_residenceType.contains('Rented')) const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _yearsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Years of Stay'),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
