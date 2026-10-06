// lib/features/search/presentation/barcode_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import 'package:trenda_shared/core/trenda_qr.dart';
import '../../../design_system/design_system.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasScanned = false;
  bool _isProcessingImage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final value = barcode.rawValue;

    if (value != null && value.isNotEmpty) {
      _processScannedValue(value);
    }
  }

  void _processScannedValue(String value) {
    if (_hasScanned) return;
    setState(() => _hasScanned = true);

    debugPrint('🔍 QR Scanned value: $value');

    // ONE parser for every Trenda code, shared with the Trenda-tab scanner
    // (trenda_shared/core/trenda_qr.dart). This replaced a hand-rolled ladder of
    // startsWith checks that had drifted from it: the two scanners in this app
    // resolved the same sticker differently.
    final target = TrendaQr.parse(value);
    if (target != null) {
      switch (target.kind) {
        case TrendaQrKind.product:
          debugPrint('📦 Product QR → ${target.id}');
          Navigator.of(context).pop();
          Future.microtask(() => context.push('/product/${target.id}'));
          return;
        case TrendaQrKind.store:
          debugPrint('🏪 Store QR → ${target.id}');
          Navigator.of(context).pop();
          Future.microtask(() => context.push('/store/${target.id}'));
          return;
        case TrendaQrKind.wholesale:
        case TrendaQrKind.supplier:
          // Vendor-app codes. Say so rather than dropping through to a barcode
          // search that will find nothing.
          debugPrint('🏭 Vendor-app QR, not resolvable here');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'This is a wholesale/supplier code — open it in the Vendor app.')),
          );
          return;
      }
    }

    // Check if this is a Trenda product code (TRD prefix)
    // These need to be looked up via the search API
    if (value.startsWith('TRD')) {
      debugPrint('🏷️ Trenda product code detected: $value');
      _lookupProductByCode(value);
      return;
    }

    // Otherwise, return as product barcode search
    debugPrint('📌 Returning scanned value for search: $value');
    context.pop(value);
  }

  /// Handle Trenda product code (TRD prefix) or unknown barcode
  void _lookupProductByCode(String code) {
    // Show a bottom sheet with options
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Barcode Scanned',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        code,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'This barcode format requires a product search. What would you like to do?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back to previous screen
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      // Navigate to search with the code
                      context.push('/search', extra: {'query': code});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadQrImage() async {
    if (_isProcessingImage) return;

    setState(() => _isProcessingImage = true);

    try {
      // Opens the device Gallery (native ACTION_PICK) and returns a file path;
      // falls back to file_picker/SAF. Avoids the system Photo Picker, which
      // crashes ("Volume external_primary not found") on some OEM/ColorOS ROMs.
      final path = await ImagePickerService().pickGalleryImagePath();

      if (path == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      // Analyze the image for barcodes
      final barcodeResult = await _controller.analyzeImage(path);

      if (barcodeResult != null && barcodeResult.barcodes.isNotEmpty) {
        final value = barcodeResult.barcodes.first.rawValue;
        if (value != null && value.isNotEmpty) {
          _processScannedValue(value);
          return;
        }
      }

      // No QR code found in image
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code found in the image'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScannerOverlayPainter(),
          ),

          // Instructions and Upload Button
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Container(
              padding: AppSpacing.paddingMD,
              child: Column(
                children: [
                  Container(
                    padding: AppSpacing.paddingSM,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppSpacing.borderRadiusMD,
                    ),
                    child: Text(
                      'Position barcode within the frame',
                      style: AppTypography.asOnDark(AppTypography.bodyMedium),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  AppSpacing.verticalMD,
                  if (_hasScanned)
                    Container(
                      padding: AppSpacing.paddingSM,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, color: Colors.white),
                          AppSpacing.horizontalXS,
                          Text(
                            'Barcode detected!',
                            style: AppTypography.asOnDark(
                                AppTypography.labelLarge),
                          ),
                        ],
                      ),
                    ),
                  AppSpacing.verticalLG,
                  // Upload QR Image Button
                  ElevatedButton.icon(
                    onPressed: _isProcessingImage ? null : _uploadQrImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: _isProcessingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library),
                    label: Text(
                      _isProcessingImage ? 'Processing...' : 'Upload QR Image',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom overlay painter for scanner
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2.5;
    final rect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Draw overlay
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paint,
    );

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const bracketLength = 30.0;
    const radius = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + bracketLength)
        ..lineTo(left, top + radius)
        ..arcToPoint(Offset(left + radius, top),
            radius: const Radius.circular(radius))
        ..lineTo(left + bracketLength, top),
      bracketPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - bracketLength, top)
        ..lineTo(left + scanAreaSize - radius, top)
        ..arcToPoint(Offset(left + scanAreaSize, top + radius),
            radius: const Radius.circular(radius))
        ..lineTo(left + scanAreaSize, top + bracketLength),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + scanAreaSize - bracketLength)
        ..lineTo(left, top + scanAreaSize - radius)
        ..arcToPoint(Offset(left + radius, top + scanAreaSize),
            radius: const Radius.circular(radius))
        ..lineTo(left + bracketLength, top + scanAreaSize),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - bracketLength, top + scanAreaSize)
        ..lineTo(left + scanAreaSize - radius, top + scanAreaSize)
        ..arcToPoint(Offset(left + scanAreaSize, top + scanAreaSize - radius),
            radius: const Radius.circular(radius))
        ..lineTo(left + scanAreaSize, top + scanAreaSize - bracketLength),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
