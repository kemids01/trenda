import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/municipality_provider.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Municipality picker. The list is whatever the server serves
/// ([availableMunicipalitiesProvider]) — never a hardcoded province.
class MunicipalitySelector extends ConsumerWidget {
  final bool showLabel;
  final EdgeInsets? padding;

  const MunicipalitySelector({
    super.key,
    this.showLabel = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMunicipality = ref.watch(municipalityProvider);
    final notifier = ref.read(municipalityProvider.notifier);
    final municipalitiesAsync = ref.watch(availableMunicipalitiesProvider);

    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Filter by Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: municipalitiesAsync.when(
              data: (municipalities) => DropdownButton<String?>(
                value: currentMunicipality,
                isExpanded: true,
                underline: const SizedBox(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                hint: Row(
                  children: [
                    Icon(Icons.public, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Text(
                      'Select Municipality/City',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                items: [
                  ...municipalities.map((municipality) {
                    return DropdownMenuItem<String>(
                      value: municipality,
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: currentMunicipality == municipality
                                ? Colors.blue
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            municipality,
                            style: TextStyle(
                              fontWeight: currentMunicipality == municipality
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: currentMunicipality == municipality
                                  ? Colors.blue
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) async {
                  await notifier.setMunicipality(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Filtering by ${value ?? "all cities"}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load locations: $err',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ),
          if (currentMunicipality != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Showing results from $currentMunicipality',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => TapGuard.run('municipality_selector.clear@154', () async {
                      await notifier.clearMunicipality();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Filter cleared'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact version for app bar or narrow spaces
class MunicipalityChip extends ConsumerWidget {
  const MunicipalityChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final municipality = ref.watch(municipalityProvider);

    if (municipality == null) {
      return const SizedBox.shrink();
    }

    return Chip(
      avatar: const Icon(Icons.location_on, size: 16),
      label: Text(
        municipality,
        style: const TextStyle(fontSize: 12),
      ),
      onDeleted: () =>
          ref.read(municipalityProvider.notifier).clearMunicipality(),
      deleteIcon: const Icon(Icons.close, size: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
