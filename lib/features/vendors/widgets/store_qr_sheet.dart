// lib/features/vendors/widgets/store_qr_sheet.dart
// Share a shop: a REAL scannable QR, a working copy button, and the system
// share sheet. The previous dialog drew an Icons.qr_code_2 glyph (nothing could
// scan it) and its "Copy Link" button only showed a snackbar — the clipboard
// call was commented out.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../stores/utils/storefront_style.dart';

/// Public web link for a store. Kept in one place so the QR, the copy button
/// and the share sheet can never drift apart.
String storeShareUrl(String vendorId) => 'https://trenda.ph/store/$vendorId';

Future<void> showStoreQrSheet(
  BuildContext context, {
  required String vendorId,
  required String storeName,
  String? logoUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StoreQrSheet(vendorId: vendorId, storeName: storeName),
  );
}

class _StoreQrSheet extends StatelessWidget {
  final String vendorId;
  final String storeName;

  const _StoreQrSheet({required this.vendorId, required this.storeName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final house = awningPaletteFor(vendorId, brightness: theme.brightness);
    final url = storeShareUrl(vendorId);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              storeName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan to visit this shop',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),

            // The QR always sits on white with a quiet zone — a themed or tinted
            // background breaks scanning.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: house.stripe.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 208,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: house.stripe,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                url,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Store link copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: house.stripe,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Share.share(
                      'Shop at $storeName on Trenda: $url',
                      subject: storeName,
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 17),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
