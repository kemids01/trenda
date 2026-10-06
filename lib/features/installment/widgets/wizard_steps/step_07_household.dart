import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step07Household extends ConsumerStatefulWidget {
  const Step07Household({super.key});

  @override
  ConsumerState<Step07Household> createState() => _Step07HouseholdState();
}

class _Step07HouseholdState extends ConsumerState<Step07Household> {
  final TextEditingController _dependentsCtrl = TextEditingController();
  final TextEditingController _workingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final household = ref.read(installmentFormProvider).formData['dependents']
            as Map<String, dynamic>? ??
        {};

    _dependentsCtrl.text = household['count']?.toString() ?? '0';
    _workingCtrl.text = household['workingMembers']?.toString() ?? '0';

    _dependentsCtrl.addListener(
        () => _update('count', int.tryParse(_dependentsCtrl.text) ?? 0));
    _workingCtrl.addListener(
        () => _update('workingMembers', int.tryParse(_workingCtrl.text) ?? 0));
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('dependents', {key: value});
  }

  @override
  void dispose() {
    _dependentsCtrl.dispose();
    _workingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Household', Icons.family_restroom_outlined,
            subtitle: 'Dependents and working family members'),
        formCard(children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dependentsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Dependents',
                      icon: Icons.child_care_outlined,
                      helper: 'Children or relatives'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _workingCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Working Members',
                      icon: Icons.groups_outlined,
                      helper: 'Including yourself'),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
