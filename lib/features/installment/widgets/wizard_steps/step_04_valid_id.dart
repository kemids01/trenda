import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import '../../../auth/data/providers.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class Step04ValidId extends ConsumerStatefulWidget {
  const Step04ValidId({super.key});

  @override
  ConsumerState<Step04ValidId> createState() => _Step04ValidIdState();
}

class _Step04ValidIdState extends ConsumerState<Step04ValidId> {
  String _idType = 'SSS';
  String? _frontUrl;
  String? _backUrl;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  bool _uploadingFront = false;
  bool _uploadingBack = false;

  static const _phIdTypes = [
    'SSS',
    'PhilHealth',
    'UMID',
    'Passport',
    "Driver's License",
    "Voter's ID",
    'PRC ID',
    'TIN ID',
    'Postal ID',
    'GSIS',
    'Senior Citizen ID',
    'National ID (PhilSys)',
  ];

  @override
  void initState() {
    super.initState();
    final personal = ref.read(installmentFormProvider).formData['personalInfo']
            as Map<String, dynamic>? ??
        {};
    if (personal['idType'] != null) _idType = personal['idType'];
    _frontUrl = personal['validIdFrontUrl'];
    _backUrl = personal['validIdBackUrl'];
  }

  void _updatePersonal(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('personalInfo', {key: value});
  }

  Future<void> _captureImage(bool isFront) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Route through the shared service: gallery uses SAF/file_picker (the
    // system Photo Picker crashes on some OEM ROMs and closes the app); camera
    // uses image_picker.
    final picked = await ImagePickerService().pickImage(
      source: source,
      maxWidth: 1200,
      quality: 85,
    );
    if (picked == null) return;

    final bytes = picked.bytes;
    setState(() {
      if (isFront) {
        _frontBytes = bytes;
        _uploadingFront = true;
      } else {
        _backBytes = bytes;
        _uploadingBack = true;
      }
    });

    try {
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final user = ref.read(authNotifierProvider).user;
      final token = await user?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse(
            '${AppConfig.backendBaseUrl}/api/installment/upload/installment-doc'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': base64Image,
          'docType': isFront ? 'valid_id_front' : 'valid_id_back',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['data']['url'] as String;
        setState(() {
          if (isFront) {
            _frontUrl = url;
            _uploadingFront = false;
          } else {
            _backUrl = url;
            _uploadingBack = false;
          }
        });
        _updatePersonal(isFront ? 'validIdFrontUrl' : 'validIdBackUrl', url);
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      setState(() {
        if (isFront)
          _uploadingFront = false;
        else
          _uploadingBack = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Valid ID Verification', Icons.credit_card_outlined,
            subtitle: 'Upload a Philippine government-issued ID'),
        formCard(children: [
          DropdownButtonFormField<String>(
            value: _idType,
            decoration:
                compactInput('ID Type', icon: Icons.assignment_ind_outlined),
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: _phIdTypes
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _idType = val);
                _updatePersonal('idType', val);
              }
            },
          ),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildIdCard(
                label: 'Front Side',
                bytes: _frontBytes,
                url: _frontUrl,
                isUploading: _uploadingFront,
                onTap: () => TapGuard.run('step_04_valid_id.captureImage', () => _captureImage(true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIdCard(
                label: 'Back Side',
                bytes: _backBytes,
                url: _backUrl,
                isUploading: _uploadingBack,
                onTap: () => TapGuard.run('step_04_valid_id.captureImage', () => _captureImage(false)),
              ),
            ),
          ],
        ),
        if (_frontUrl != null && _backUrl != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text('Both sides uploaded successfully',
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade700)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIdCard({
    required String label,
    Uint8List? bytes,
    String? url,
    required bool isUploading,
    required VoidCallback onTap,
  }) {
    return formCard(children: [
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: url != null ? Colors.green.shade300 : Colors.grey.shade300,
              style: url != null ? BorderStyle.solid : BorderStyle.none,
            ),
            image: bytes != null
                ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                : url != null
                    ? DecorationImage(
                        image: NetworkImage(url), fit: BoxFit.cover)
                    : null,
          ),
          child: bytes == null && url == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 28, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text('Tap to capture',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : null,
        ),
      ),
      if (isUploading) ...[
        const SizedBox(height: 6),
        const LinearProgressIndicator(minHeight: 2),
      ],
    ]);
  }
}
