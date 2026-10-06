// lib/features/home/presentation/widgets/official_qr_scan.dart
// The Official Trenda QR flow: a full-screen camera scanner plus the dispatch
// that turns a decoded `trenda://<kind>/<id>` into a route.
//
// Lives outside the Trenda hub because the scan button now sits in the shop
// dock (above the bottom nav) rather than inside the hub's own header.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trenda_shared/trenda_shared.dart';

/// Scan an Official Trenda QR and open the matching store product.
///
/// Wholesale/supplier codes are for the vendor (B2B) app — they are recognised
/// and explained here rather than failing as "unknown".
Future<void> scanOfficialQr(BuildContext context) async {
  final raw = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const OfficialQrScanScreen()),
  );
  if (raw == null || !context.mounted) return;

  final t = TrendaQr.parse(raw);
  if (t == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That is not a Trenda code')),
    );
    return;
  }
  switch (t.kind) {
    case TrendaQrKind.product:
      context.push('/product/${t.id}');
    case TrendaQrKind.store:
      // A shop code. This used to be read as a product and pushed
      // /product/<vendorId> — a product page for a vendor id.
      context.push('/store/${t.id}');
    case TrendaQrKind.wholesale:
    case TrendaQrKind.supplier:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This is a wholesale/supplier code — not available in the store.')),
      );
  }
}

/// What a scan on the Stores page resolved to: a store id to open, or the
/// message to show instead. Pure, so the store-only rule is unit-testable.
({String? storeId, String? message}) resolveStoreScan(String raw) {
  final t = TrendaQr.parse(raw);
  if (t == null) return (storeId: null, message: 'That is not a Trenda code');
  if (t.kind != TrendaQrKind.store) {
    // The Stores page scanner is for shop codes only; product codes are
    // scanned from the Shop tab dock.
    return (
      storeId: null,
      message: 'This is not a store QR. Scan the QR a shop displays.'
    );
  }
  return (storeId: t.id, message: null);
}

/// Scan a shop's Trenda QR from the Stores page and open that store. Any other
/// Trenda code (product, wholesale, supplier) is refused, not followed.
Future<void> scanStoreQr(BuildContext context) async {
  final raw = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => const OfficialQrScanScreen(
        title: 'Scan store QR',
        hint: 'Point the camera at a shop\'s Trenda QR',
      ),
    ),
  );
  if (raw == null || !context.mounted) return;
  final r = resolveStoreScan(raw);
  if (r.storeId != null) {
    context.push('/store/${r.storeId}');
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(r.message!)));
  }
}

/// Full-screen camera QR scanner. Pops the first decoded value to the caller.
class OfficialQrScanScreen extends StatefulWidget {
  const OfficialQrScanScreen({
    super.key,
    this.title = 'Scan product QR',
    this.hint = 'Point the camera at an Official Trenda product QR',
  });

  final String title;
  final String hint;

  @override
  State<OfficialQrScanScreen> createState() => _OfficialQrScanScreenState();
}

class _OfficialQrScanScreenState extends State<OfficialQrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              final code = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              if (code != null && code.trim().isNotEmpty) {
                _handled = true;
                Navigator.of(context).pop(code);
              }
            },
          ),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Text(
              widget.hint,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
