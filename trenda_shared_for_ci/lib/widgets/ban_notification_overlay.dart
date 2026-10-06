// trenda_shared/lib/widgets/ban_notification_overlay.dart
// Reusable overlay widget that shows ban/unban popup dialogs
import 'package:flutter/material.dart';
import '../core/timezone.dart';
import 'package:intl/intl.dart';

/// Shows a ban notification dialog
/// Call this from your widget when a ban event is received
void showBanNotificationDialog(
  BuildContext context, {
  required bool isBanned,
  String scope = 'chat',
  String banType = 'temporary',
  String reason = 'Policy violation',
  String? expiresAt,
}) {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: !isBanned,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        isBanned ? Icons.block : Icons.check_circle,
        size: 56,
        color: isBanned ? Colors.red : Colors.green,
      ),
      title: Text(
        isBanned ? 'Account Restricted' : 'Restriction Removed',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isBanned ? Colors.red.shade800 : Colors.green.shade800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBanned) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scope == 'app'
                              ? 'Your access to the app has been restricted.'
                              : 'Your chat access has been restricted.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Reason', value: reason),
                  _InfoRow(
                    label: 'Duration',
                    value: banType == 'permanent'
                        ? 'Permanent'
                        : 'Temporary${expiresAt != null ? ' (until ${_formatDate(expiresAt)})' : ''}',
                  ),
                  _InfoRow(
                    label: 'Scope',
                    value: scope == 'app' ? 'Full App Access' : 'Chat Feature',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If you believe this is a mistake, please contact support.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration,
                      size: 24, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scope == 'app'
                          ? 'Your full app access has been restored.'
                          : 'Your chat access has been restored. You can now send messages again.',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBanned ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isBanned ? 'I Understand' : 'Great!'),
          ),
        ),
      ],
    ),
  );
}

String _formatDate(String? dateStr) {
  if (dateStr == null) return 'N/A';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('M/d/y').formatPh(date);
  } catch (_) {
    return dateStr;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
