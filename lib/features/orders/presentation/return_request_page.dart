// lib/features/orders/presentation/return_request_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/images/picked_image.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import '../../../design_system/app_colors.dart';
import '../data/orders_repository.dart';
import 'return_guide_info_page.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class ReturnRequestPage extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final List<Map<String, dynamic>> items;

  const ReturnRequestPage({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.items,
  });

  @override
  ConsumerState<ReturnRequestPage> createState() => _ReturnRequestPageState();
}

class _ReturnRequestPageState extends ConsumerState<ReturnRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _showGuide = true;
  String _returnType = 'return'; // 'return' or 'exchange'

  // Per-item return selection
  final Map<String, bool> _selectedItems = {};
  final Map<String, String> _itemReasons = {};
  final Map<String, String?> _itemConditions = {};
  final Map<String, TextEditingController> _itemDetailsControllers = {};

  // Image evidence
  final List<PickedImage> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isUploadingImages = false;

  static const _returnReasons = [
    {'value': 'defective', 'label': 'Defective / Not working'},
    {'value': 'wrong_item', 'label': 'Received wrong item'},
    {'value': 'not_as_described', 'label': 'Not as described'},
    {'value': 'damaged', 'label': 'Arrived damaged'},
    {'value': 'size_issue', 'label': 'Size / fit issue'},
    {'value': 'quality_issue', 'label': 'Quality issue'},
    {'value': 'other', 'label': 'Other'},
  ];

  // Reasons that qualify for exchange (vendor-fault)
  static const _exchangeEligibleReasons = [
    'defective', 'wrong_item', 'not_as_described', 'damaged'
  ];

  static const _conditions = [
    {'value': 'unopened', 'label': 'Unopened / Sealed'},
    {'value': 'opened_unused', 'label': 'Opened but unused'},
    {'value': 'used', 'label': 'Used'},
    {'value': 'damaged', 'label': 'Damaged'},
  ];

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final id = item['id']?.toString() ?? item['productId']?.toString() ?? '';
      _selectedItems[id] = false;
      _itemReasons[id] = 'defective';
      _itemConditions[id] = 'unopened';
      _itemDetailsControllers[id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _itemDetailsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _selectedCount => _selectedItems.values.where((v) => v).length;

  bool get _canExchange {
    if (_selectedCount == 0) return false;
    // All selected items must have exchange-eligible reasons
    for (final item in widget.items) {
      final id = item['id']?.toString() ?? item['productId']?.toString() ?? '';
      if (_selectedItems[id] != true) continue;
      final reason = _itemReasons[id] ?? 'defective';
      if (!_exchangeEligibleReasons.contains(reason)) return false;
    }
    return true;
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final returnItems = <Map<String, dynamic>>[];
      for (final item in widget.items) {
        final id = item['id']?.toString() ?? item['productId']?.toString() ?? '';
        if (_selectedItems[id] != true) continue;

        returnItems.add({
          'productId': item['productId'] ?? id,
          'quantity': item['quantity'] ?? 1,
          'reason': _itemReasons[id] ?? 'defective',
          if (_itemDetailsControllers[id]?.text.isNotEmpty == true)
            'reasonDetails': _itemDetailsControllers[id]!.text,
          if (_itemConditions[id] != null)
            'condition': _itemConditions[id],
        });
      }

      final response = await OrdersRepository().createReturn(
        orderId: widget.orderId,
        items: returnItems,
        customerNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
        type: _returnType,
        images: _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls : null,
      );

      if (mounted) {
        final returnNumber = response['returnNumber'] ?? '';
        final displayNumber = returnNumber.isNotEmpty ? ' #$returnNumber' : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_returnType == 'exchange'
                ? 'Exchange request$displayNumber submitted! It will be reviewed and a replacement sent.'
                : 'Return request$displayNumber submitted! You will be notified once it is reviewed.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Track Return',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to My Returns page
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit return: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Return'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Returns & Exchanges Guide',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReturnGuideInfoPage()),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Guide banner
            if (_showGuide)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('How Returns & Exchanges Work',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade800, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '1. Select items and choose Return (refund) or Exchange (same product)\n'
                                '2. Exchange is available for: defective, damaged, wrong item\n'
                                '3. The vendor reviews your request (1-2 business days)\n'
                                '4. If approved, a rider will be sent to pick up your item\n'
                                '5. For exchanges, the same rider delivers the replacement',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _showGuide = false),
                          child: Icon(Icons.close, size: 16, color: Colors.blue.shade400),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReturnGuideInfoPage()),
                        ),
                        child: Row(
                          children: [
                            const Spacer(),
                            Text(
                              'Read Full Guide →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Return Type Selector
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('What would you like?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  ),
                  RadioGroup<String>(
                    groupValue: _returnType,
                    onChanged: (v) {
                      if (v == 'exchange' && !_canExchange) return;
                      if (v != null) setState(() => _returnType = v);
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Return & Refund', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('Get your money back', style: TextStyle(fontSize: 12)),
                          secondary: const Icon(Icons.currency_exchange, color: Colors.orange),
                          value: 'return',
                          activeColor: AppColors.primary,
                          dense: true,
                        ),
                        RadioListTile<String>(
                          title: const Text('Exchange (Same Product)', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            _canExchange
                                ? 'Receive a brand new replacement'
                                : 'Only for: defective, damaged, wrong item',
                            style: TextStyle(fontSize: 12, color: !_canExchange ? Colors.red.shade400 : null),
                          ),
                          secondary: Icon(Icons.swap_horiz, color: _canExchange ? Colors.green : Colors.grey),
                          value: 'exchange',
                          activeColor: Colors.green,
                          toggleable: !_canExchange ? false : true,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Order Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ${widget.orderNumber}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${widget.items.length} item(s)',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedCount > 0 ? AppColors.primary.withAlpha(25) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_selectedCount selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedCount > 0 ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            const Text('Select Items to Return',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Tap an item to expand return options',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),

            ...widget.items.map((item) {
              final id = item['id']?.toString() ?? item['productId']?.toString() ?? '';
              final isSelected = _selectedItems[id] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: isSelected ? 1.5 : 0,
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: Text(item['name'] ?? 'Unknown Item',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Qty: ${item['quantity'] ?? 1} × ₱${item['price'] ?? 0}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      value: isSelected,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _selectedItems[id] = v ?? false),
                      secondary: item['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(item['image'], width: 48, height: 48, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48, height: 48,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, size: 24),
                                )),
                            )
                          : null,
                    ),

                    // Expanded return options
                    if (isSelected) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reason
                            const Text('Reason for return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _itemReasons[id],
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _returnReasons.map((r) =>
                                DropdownMenuItem(value: r['value'], child: Text(r['label']!, style: const TextStyle(fontSize: 13)))
                              ).toList(),
                              onChanged: (v) => setState(() => _itemReasons[id] = v ?? 'defective'),
                            ),

                            const SizedBox(height: 10),

                            // Condition
                            const Text('Item condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _conditions.map((c) {
                                final isActive = _itemConditions[id] == c['value'];
                                return ChoiceChip(
                                  label: Text(c['label']!, style: TextStyle(fontSize: 11, color: isActive ? Colors.white : null)),
                                  selected: isActive,
                                  selectedColor: AppColors.primary,
                                  onSelected: (_) => setState(() => _itemConditions[id] = c['value']),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 10),

                            // Details
                            TextFormField(
                              controller: _itemDetailsControllers[id],
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Additional details (optional)',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Overall notes
            const Text('Additional Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any other details about your return...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),

            const SizedBox(height: 20),

            // Photo evidence section
            const Text('Photo Evidence (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Add photos of defective/damaged items to speed up your return',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 10),
            _buildImagePickerSection(),

            const SizedBox(height: 24),

            // Submit
            ElevatedButton(
              onPressed: _isSubmitting || _selectedCount == 0 ? null : () => TapGuard.run('return_request.submitReturn', _submitReturn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selectedCount == 0
                          ? 'Select items first'
                          : _returnType == 'exchange'
                              ? 'Request Exchange ($_selectedCount item${_selectedCount > 1 ? 's' : ''})'
                              : 'Submit Return Request ($_selectedCount item${_selectedCount > 1 ? 's' : ''})',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 12),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Items must be in their original condition when possible. '
                      'Returns are reviewed within 1-2 business days.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // IMAGE PICKER SECTION
  // ===========================================================================

  Widget _buildImagePickerSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image grid
          if (_selectedImages.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  final isUploaded = index < _uploadedImageUrls.length;

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          image.bytes,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Upload status indicator
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isUploaded ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isUploaded ? Icons.check : Icons.upload,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                              if (index < _uploadedImageUrls.length) {
                                _uploadedImageUrls.removeAt(index);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Add photo button
          Row(
            children: [
              OutlinedButton.icon(
                onPressed:
                    _isUploadingImages || _selectedImages.length >= 5
                        ? null
                        : () => TapGuard.run('return_request.pickImages', _pickImages),
                icon: _isUploadingImages
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate, size: 18),
                label: Text(
                  _isUploadingImages
                      ? 'Uploading...'
                      : _selectedImages.isEmpty
                          ? 'Add Photos'
                          : 'Add More (${_selectedImages.length}/5)',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${_uploadedImageUrls.length}/${_selectedImages.length} uploaded',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),

          if (_selectedImages.length >= 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Maximum 5 photos allowed',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final service = ImagePickerService();

    if (source == ImageSource.gallery) {
      final remaining = 5 - _selectedImages.length;
      final picks = await service.pickMultiple(
        maxCount: remaining,
        maxWidth: 1024,
        quality: 80,
      );

      for (final pick in picks) {
        setState(() => _selectedImages.add(pick));
        await _uploadImage(pick);
      }
    } else {
      final pick = await service.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        quality: 80,
      );
      if (pick == null) return;

      setState(() => _selectedImages.add(pick));
      await _uploadImage(pick);
    }
  }

  Future<void> _uploadImage(PickedImage image) async {
    setState(() => _isUploadingImages = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final token = await user.getIdToken();

      final dio = Dio(BaseOptions(baseUrl: AppConfig.backendBaseUrl));
      // POST /api/upload/:folder reads multer field 'file' and takes the folder from the
      // PATH. An 'image' field is refused outright (LIMIT_UNEXPECTED_FILE → 500), which is
      // how every return photo failed to upload.
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          image.bytes,
          filename: 'return_${DateTime.now().millisecondsSinceEpoch}.jpg',
          // Without it the server builds a data:application/octet-stream URI.
          contentType: MediaType.parse(image.mimeType),
        ),
      });

      final response = await dio.post(
        '/api/upload/return-evidence',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final url = response.data['url'] ?? response.data['secure_url'] ?? '';
      if (url.isNotEmpty) {
        setState(() => _uploadedImageUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }
}
