// lib/features/home/presentation/widgets/municipality_pill.dart
// The "Shopping in <city>" pill that sits beside the brand mark in the app bar.
//
// It used to live under the Shop tab's own header, where it was invisible from
// every other tab — yet the municipality scopes prices, shelves, delivery fees
// and riders app-wide. In the bar it is always on screen, and tapping it opens
// the city picker page (`/city`) — it used to open the Local tab, which became
// the Food tab on 2026-09-25.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/municipality_provider.dart';

class MunicipalityPill extends ConsumerWidget {
  const MunicipalityPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final municipality = ref.watch(municipalityProvider)?.trim();
    final chosen = municipality != null && municipality.isNotEmpty;

    return InkWell(
      onTap: () => context.push('/city'),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
        decoration: BoxDecoration(
          // An unset city is a prompt, not a status — it is tinted to be noticed.
          color: (chosen ? scheme.primary : scheme.error)
              .withValues(alpha: chosen ? 0.09 : 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (chosen ? scheme.primary : scheme.error)
                .withValues(alpha: chosen ? 0.2 : 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chosen
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              size: 13,
              color: chosen ? scheme.primary : scheme.error,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                chosen ? municipality : 'Pick city',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: chosen
                      ? scheme.onSurface.withValues(alpha: 0.78)
                      : scheme.error,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
