// lib/features/core/widgets/official_tag.dart
// Small gold "Official Trenda" pill for first-party items on cart / order surfaces, so the
// Official Trenda provenance stays visible after a product leaves its detail card.
import 'package:flutter/material.dart';

class OfficialTag extends StatelessWidget {
  const OfficialTag({super.key, this.label = 'Official Trenda', this.compact = false});

  final String label;
  final bool compact;

  static const Color _gold = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: compact ? 11 : 13, color: _gold),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }
}
