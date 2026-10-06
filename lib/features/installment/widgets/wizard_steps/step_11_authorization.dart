import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';

class Step11Authorization extends ConsumerStatefulWidget {
  const Step11Authorization({super.key});

  @override
  ConsumerState<Step11Authorization> createState() =>
      _Step11AuthorizationState();
}

class _Step11AuthorizationState extends ConsumerState<Step11Authorization> {
  bool _certify = false;
  bool _agreeTerms = false;
  final TextEditingController _signatureCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = ref.read(installmentFormProvider).formData['authorization']
            as Map<String, dynamic>? ??
        {};

    _certify = auth['certify'] ?? false;
    _agreeTerms = auth['agreeTerms'] ?? false;
    _signatureCtrl.text = auth['signatureName'] ?? '';

    _signatureCtrl
        .addListener(() => _update('signatureName', _signatureCtrl.text));
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('authorization', {key: value});
  }

  @override
  void dispose() {
    _signatureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Authorization', Icons.verified_user_outlined,
            subtitle: 'Certify and sign your application'),
        formCard(children: [
          CheckboxListTile(
            value: _certify,
            onChanged: (val) {
              setState(() => _certify = val ?? false);
              _update('certify', _certify);
            },
            title: const Text(
                'I certify that all information provided is true and correct.',
                style: TextStyle(fontSize: 12)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
          CheckboxListTile(
            value: _agreeTerms,
            onChanged: (val) {
              setState(() => _agreeTerms = val ?? false);
              _update('agreeTerms', _agreeTerms);
            },
            title: const Text(
                'I agree to the Terms & Conditions and Privacy Policy.',
                style: TextStyle(fontSize: 12)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ]),
        const SizedBox(height: 10),
        formCard(children: [
          Row(
            children: [
              Icon(Icons.draw_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text('Digital Signature',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _signatureCtrl,
            decoration: compactInput('Type your full legal name',
                icon: Icons.edit_outlined,
                helper:
                    'By typing your name, you execute this digital signature.'),
            textCapitalization: TextCapitalization.words,
          ),
        ]),
      ],
    );
  }
}
