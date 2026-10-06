import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step06References extends ConsumerStatefulWidget {
  const Step06References({super.key});

  @override
  ConsumerState<Step06References> createState() => _Step06ReferencesState();
}

class _Step06ReferencesState extends ConsumerState<Step06References> {
  final List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    final List refs =
        ref.read(installmentFormProvider).formData['references'] ?? [];

    for (int i = 0; i < 3; i++) {
      final refData = (i < refs.length && refs[i] is Map) ? refs[i] as Map : {};
      _controllers.add({
        'name': TextEditingController(text: refData['name']?.toString()),
        'relation':
            TextEditingController(text: refData['relation']?.toString()),
        'contact': TextEditingController(text: refData['contact']?.toString()),
      });

      _controllers[i]['name']!.addListener(_save);
      _controllers[i]['relation']!.addListener(_save);
      _controllers[i]['contact']!.addListener(_save);
    }
  }

  void _save() {
    final List<Map<String, String>> data = _controllers
        .map((c) => {
              'name': c['name']!.text,
              'relation': c['relation']!.text,
              'contact': c['contact']!.text,
            })
        .toList();
    ref.read(installmentFormProvider.notifier).updateRoot('references', data);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.values.forEach((ctrl) => ctrl.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Personal References', Icons.people_outline,
            subtitle: 'Provide at least 3 character references'),
        for (int i = 0; i < 3; i++) ...[
          _buildReferenceCard(i),
          if (i < 2) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildReferenceCard(int index) {
    return formCard(children: [
      Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800)),
            ),
          ),
          const SizedBox(width: 8),
          Text('Reference ${index + 1}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _controllers[index]['name'],
        decoration: compactInput('Full Name'),
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _controllers[index]['relation'],
              decoration: compactInput('Relationship'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _controllers[index]['contact'],
              keyboardType: TextInputType.phone,
              decoration: compactInput('Contact No.'),
            ),
          ),
        ],
      ),
    ]);
  }
}
