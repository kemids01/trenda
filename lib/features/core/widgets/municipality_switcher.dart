import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/municipality_provider.dart';

/// Compact municipality switcher for use in the AppBar.
/// Shows the current browsing municipality and allows switching.
/// When browsing a non-home municipality, shows an indicator banner.
class MunicipalitySwitcher extends ConsumerWidget {
  const MunicipalitySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMuni = ref.watch(municipalityProvider);
    final homeMuni = ref.watch(homeMunicipalityProvider);
    final isBrowsingOther = currentMuni != null &&
        homeMuni != null &&
        currentMuni.toLowerCase() != homeMuni.toLowerCase();
    final label = currentMuni ?? 'Select area';

    return GestureDetector(
      onTap: () => _showMunicipalityPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isBrowsingOther
              ? Colors.orange.withOpacity(0.2)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: isBrowsingOther
              ? Border.all(color: Colors.orange.shade300, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBrowsingOther ? Icons.explore : Icons.location_on,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  void _showMunicipalityPicker(BuildContext context, WidgetRef ref) {
    final municipalitiesAsync = ref.read(availableMunicipalitiesProvider);
    final currentMuni = ref.read(municipalityProvider);
    final homeMuni = ref.read(homeMunicipalityProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.explore, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Browse by Municipality',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Info banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You can browse products from other municipalities, but ordering is only available in your home area.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // List
                Expanded(
                  child: municipalitiesAsync.when(
                    data: (municipalities) {
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: municipalities.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (_, index) {
                          final muni = municipalities[index];
                          final isSelected = currentMuni != null &&
                              muni.toLowerCase() == currentMuni.toLowerCase();
                          final isHome = homeMuni != null &&
                              muni.toLowerCase() == homeMuni.toLowerCase();

                          return ListTile(
                            leading: Icon(
                              isHome ? Icons.home : Icons.location_city,
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey,
                            ),
                            title: Text(
                              muni,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.black87,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isHome)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'HOME',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(Icons.check_circle,
                                        color: Colors.blue.shade700, size: 20),
                                  ),
                              ],
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onTap: () {
                              ref
                                  .read(municipalityProvider.notifier)
                                  .setMunicipality(muni);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) => const Center(
                      child: Text('Failed to load municipalities'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
