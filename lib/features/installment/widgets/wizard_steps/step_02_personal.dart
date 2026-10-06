import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';
import 'package:trenda_shared/core/timezone.dart';

class Step02Personal extends ConsumerStatefulWidget {
  const Step02Personal({super.key});

  @override
  ConsumerState<Step02Personal> createState() => _Step02PersonalState();
}

class _Step02PersonalState extends ConsumerState<Step02Personal> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  String _gender = 'Male';
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final personal = ref.read(installmentFormProvider).formData['personalInfo']
            as Map<String, dynamic>? ??
        {};

    _firstNameCtrl = TextEditingController(text: personal['firstName']);
    _lastNameCtrl = TextEditingController(text: personal['lastName']);
    _mobileCtrl = TextEditingController(text: personal['mobileNumber']);
    _emailCtrl = TextEditingController(text: personal['email']);
    if (personal['gender'] != null) _gender = personal['gender'];
    if (personal['dateOfBirth'] != null) {
      _birthday = DateTime.tryParse(personal['dateOfBirth'].toString());
    }

    _firstNameCtrl.addListener(() => _update('firstName', _firstNameCtrl.text));
    _lastNameCtrl.addListener(() => _update('lastName', _lastNameCtrl.text));
    _mobileCtrl.addListener(() => _update('mobileNumber', _mobileCtrl.text));
    _emailCtrl.addListener(() => _update('email', _emailCtrl.text));
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('personalInfo', {key: value});
  }

  int? get _age {
    if (_birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - _birthday!.year;
    if (now.month < _birthday!.month ||
        (now.month == _birthday!.month && now.day < _birthday!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() => _birthday = picked);
      _update('dateOfBirth', picked.toIso8601String());
      _update('age', _age);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Personal Information', Icons.person_outline,
            subtitle: 'Basic applicant details'),
        formCard(children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameCtrl,
                  decoration:
                      compactInput('First Name', icon: Icons.badge_outlined),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lastNameCtrl,
                  decoration: compactInput('Last Name'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          fieldGap,
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: compactInput('Gender', icon: Icons.wc_outlined),
                  isDense: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: ['Male', 'Female', 'Prefer not to say']
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _gender = val);
                      _update('gender', val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickBirthday,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: compactInput(
                        _birthday != null
                            ? DateFormat('MMM dd, yyyy').formatPh(_birthday!)
                            : 'Birthday',
                        icon: Icons.cake_outlined,
                        helper: _age != null ? 'Age: $_age years old' : null,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: _birthday != null
                            ? Colors.black87
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          fieldGap,
          TextFormField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            decoration: compactInput('Mobile Number',
                icon: Icons.phone_outlined, prefix: '+63 '),
          ),
          fieldGap,
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration:
                compactInput('Email Address', icon: Icons.email_outlined),
          ),
        ]),
      ],
    );
  }
}
