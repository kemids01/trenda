import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import '../../../auth/data/providers.dart';
import '../../providers/application_form_provider.dart';
import 'form_helpers.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class Step03Selfie extends ConsumerStatefulWidget {
  const Step03Selfie({super.key});

  @override
  ConsumerState<Step03Selfie> createState() => _Step03SelfieState();
}

class _Step03SelfieState extends ConsumerState<Step03Selfie> {
  String? _photoUrl;
  Uint8List? _capturedBytes;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final personal = ref.read(installmentFormProvider).formData['personalInfo']
            as Map<String, dynamic>? ??
        {};
    _photoUrl = personal['photoUrl'];
  }

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    setState(() {
      _capturedBytes = bytes;
      _isUploading = true;
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
          'docType': 'selfie',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['data']['url'] as String;
        setState(() {
          _photoUrl = url;
          _isUploading = false;
        });
        ref
            .read(installmentFormProvider.notifier)
            .updateSection('personalInfo', {'photoUrl': url});
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      setState(() => _isUploading = false);
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
        sectionHeader('Selfie Verification', Icons.camera_front_outlined,
            subtitle: 'Take a live photo for identity verification'),
        formCard(children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                    border: Border.all(
                      color: _photoUrl != null
                          ? Colors.green.shade400
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                    image: _capturedBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_capturedBytes!),
                            fit: BoxFit.cover,
                          )
                        : _photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: _capturedBytes == null && _photoUrl == null
                      ? Icon(Icons.person_outline,
                          size: 64, color: Colors.grey.shade400)
                      : null,
                ),
                const SizedBox(height: 16),
                if (_isUploading)
                  const Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 8),
                      Text('Uploading...', style: TextStyle(fontSize: 12)),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: () => TapGuard.run('step_03_selfie.takeSelfie', _takeSelfie),
                    icon: Icon(
                      _photoUrl != null ? Icons.refresh : Icons.camera_alt,
                      size: 18,
                    ),
                    label: Text(
                      _photoUrl != null ? 'Retake Photo' : 'Take Selfie',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                    ),
                  ),
                if (_photoUrl != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text('Photo uploaded successfully',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green.shade700)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Please ensure your face is clearly visible, well-lit, and without any obstructions.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
