// trenda_frontend/lib/features/wallet/screens/customer_recharge_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/images/picked_image.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import '../providers/customer_wallet_provider.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class CustomerRechargeScreen extends ConsumerStatefulWidget {
  const CustomerRechargeScreen({super.key});

  @override
  ConsumerState<CustomerRechargeScreen> createState() =>
      _CustomerRechargeScreenState();
}

class _CustomerRechargeScreenState
    extends ConsumerState<CustomerRechargeScreen> {
  final _amountController = TextEditingController();
  Map<String, dynamic>? _selectedMethod;
  PickedImage? _receiptImage;
  bool _isUploading = false;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final methodsAsync = ref.watch(activePaymentMethodsProvider);
    final reqState = ref.watch(rechargeRequestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recharge Wallet')),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              const Text('Failed to load payment methods'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(activePaymentMethodsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (methods) {
          if (methods.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No payment methods available',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please contact support for recharge options.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Input
                Text('Recharge Amount',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Quick amount buttons
                Wrap(
                  spacing: 8,
                  children: [100, 500, 1000, 2000, 5000].map((amt) {
                    return ActionChip(
                      label: Text('₱$amt'),
                      onPressed: () => _amountController.text = amt.toString(),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Payment Method Selection
                Text('Payment Method',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...methods.map((method) {
                  final isSelected = _selectedMethod?['_id'] == method['_id'];
                  return _PaymentMethodTile(
                    method: method,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedMethod = method),
                  );
                }),

                // Payment Details (when selected)
                if (_selectedMethod != null) ...[
                  const SizedBox(height: 16),
                  _PaymentDetailsCard(method: _selectedMethod!, isDark: isDark),
                ],

                const SizedBox(height: 24),

                // Receipt Upload
                Text('Upload Receipt',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ReceiptUploadArea(
                  image: _receiptImage,
                  isUploading: _isUploading,
                  onPick: () => TapGuard.run('customer_recharge.pickImage', _pickImage),
                  onRemove: () => setState(() {
                    _receiptImage = null;
                    _uploadedImageUrl = null;
                  }),
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: reqState.isSubmitting ? null : () => TapGuard.run('customer_recharge.submitRequest', _submitRequest),
                    icon: reqState.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 20),
                    label: Text(reqState.isSubmitting
                        ? 'Submitting...'
                        : 'Submit Recharge Request'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

                if (reqState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      reqState.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePickerService().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      quality: 85,
    );
    if (picked == null) return;

    setState(() {
      _receiptImage = picked;
      _isUploading = true;
      _uploadedImageUrl = null;
    });

    try {
      // Upload to backend/Cloudinary
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final token = await user.getIdToken();

      final dio = Dio(BaseOptions(baseUrl: AppConfig.backendBaseUrl));
      // POST /api/upload/:folder reads multer field 'file' and takes the folder from the
      // PATH. An 'image' field is refused outright (LIMIT_UNEXPECTED_FILE → 500), which is
      // how every receipt failed to upload.
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(picked.bytes,
            filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
            // Without it the server builds a data:application/octet-stream URI.
            contentType: MediaType.parse(picked.mimeType)),
      });

      final response = await dio.post(
        '/api/upload/wallet-receipts',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final url = response.data['url'] ?? response.data['secure_url'] ?? '';

      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount (minimum ₱1)')),
      );
      return;
    }

    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    if (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your payment receipt')),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Recharge Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(Icons.money, 'Amount', '₱${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _ConfirmRow(
                Icons.payment, 'Method', _selectedMethod!['name'] ?? ''),
            const SizedBox(height: 8),
            _ConfirmRow(Icons.receipt, 'Receipt', 'Uploaded ✓'),
            const SizedBox(height: 16),
            const Text(
              'Your request will be reviewed by an admin. '
              'Funds will be credited once approved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success =
        await ref.read(rechargeRequestProvider.notifier).submitRequest(
              amount: amount,
              paymentMethodId: _selectedMethod!['_id'],
              receiptImage: _uploadedImageUrl!,
            );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recharge request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

// ============================================================================
// PAYMENT METHOD TILE
// ============================================================================

class _PaymentMethodTile extends StatelessWidget {
  final Map<String, dynamic> method;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = method['type'] ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'gcash':
        icon = Icons.phone_android;
        color = Colors.blue;
        break;
      case 'maya':
        icon = Icons.phone_iphone;
        color = Colors.green;
        break;
      case 'bank':
        icon = Icons.account_balance;
        color = Colors.purple;
        break;
      default:
        icon = Icons.payment;
        color = Colors.grey;
    }

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? (isDark ? Colors.blue[900] : Colors.blue[50])
          : (isDark ? Colors.grey[850] : Colors.grey[50]),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(method['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(type.toString().toUpperCase(),
            style: const TextStyle(fontSize: 12)),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : const Icon(Icons.radio_button_off, color: Colors.grey),
      ),
    );
  }
}

// ============================================================================
// PAYMENT DETAILS CARD
// ============================================================================

class _PaymentDetailsCard extends StatelessWidget {
  final Map<String, dynamic> method;
  final bool isDark;

  const _PaymentDetailsCard({required this.method, required this.isDark});

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Copied: $text'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? Colors.grey[850] : Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(),
            _DetailRow(
              label: 'Account Name',
              value: method['accountName'] ?? '',
              onCopy: () => _copy(context, method['accountName'] ?? ''),
            ),
            _DetailRow(
              label: 'Account Number',
              value: method['accountNumber'] ?? '',
              onCopy: () => _copy(context, method['accountNumber'] ?? ''),
            ),
            if (method['bankName'] != null)
              _DetailRow(
                label: 'Bank',
                value: method['bankName'],
                onCopy: () => _copy(context, method['bankName'] ?? ''),
              ),
            if (method['instructions'] != null &&
                method['instructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                method['instructions'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Row(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: onCopy,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECEIPT UPLOAD AREA
// ============================================================================

class _ReceiptUploadArea extends StatelessWidget {
  final PickedImage? image;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ReceiptUploadArea({
    required this.image,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              image!.bytes,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text('Uploading...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withOpacity(0.05),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Tap to upload receipt',
                  style: TextStyle(color: Colors.grey)),
              SizedBox(height: 4),
              Text('JPG, PNG • Max 5MB',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONFIRM ROW
// ============================================================================

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
