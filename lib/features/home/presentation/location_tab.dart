// lib/features/home/presentation/location_tab.dart
// City picker — where the shopper picks the municipality every price, shelf
// and delivery fee in the app is scoped to. Was the LOCAL tab (main_screen
// index 2) until 2026-09-25; now shown by CityPickerPage at `/city`, opened
// from the header city pill.
//
// Design: an "ink map" hero (deep indigo, contour rings) carrying the current
// city, then a searchable city list. Fully theme-driven, so it holds up in dark
// mode (the previous version hardcoded Colors.blue.* and went unreadable).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/municipality_provider.dart';
import 'package:trenda_shared/core/taps/taps.dart';

const Color _kInk = Color(0xFF0B1B4D);
const Color _kBlue = Color(0xFF2563EB);
const Color _kSky = Color(0xFF3B82F6);
const Color _kGold = Color(0xFFD4AF37);

/// Location settings tab for selecting the municipality/city filter.
class LocationTab extends ConsumerStatefulWidget {
  const LocationTab({super.key});

  @override
  ConsumerState<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends ConsumerState<LocationTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _select(String municipality) async {
    await ref.read(municipalityProvider.notifier).setMunicipality(municipality);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now shopping in $municipality'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.watch(municipalityProvider);
    final home = ref.watch(homeMunicipalityProvider);
    final away = ref.watch(isBrowsingOtherMunicipalityProvider);
    final citiesAsync = ref.watch(availableMunicipalitiesProvider);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1116) : const Color(0xFFF4F6F8),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: _LocationHero(current: current, home: home, away: away),
              ),
            ),
            if (away && home != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _AwayNotice(
                    home: home,
                    onGoHome: () => _select(home),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                child: Row(
                  children: [
                    Text(
                      'CHOOSE A CITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    citiesAsync.maybeWhen(
                      data: (list) => Text(
                        '${list.length} served',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ),
            ),
            citiesAsync.when(
              data: (cities) {
                final q = _query.trim().toLowerCase();
                final matches = q.isEmpty
                    ? cities
                    : cities
                        .where((c) => c.toLowerCase().contains(q))
                        .toList();
                if (matches.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(query: _query.trim()),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  sliver: SliverList.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final city = matches[i];
                      return _CityRow(
                        name: city,
                        selected: current == city,
                        isHome: home != null &&
                            home.toLowerCase() == city.toLowerCase(),
                        onTap: () => TapGuard.run('location.select', () => _select(city)),
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: _CityListSkeleton()),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(availableMunicipalitiesProvider),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 32),
                child: _WhyCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The current-location hero: an ink-map panel that states, unmissably, which
/// municipality the whole app is currently scoped to.
class _LocationHero extends StatelessWidget {
  final String? current;
  final String? home;
  final bool away;

  const _LocationHero({
    required this.current,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    final hasCity = (current ?? '').trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_kInk, Color(0xFF1B357F), _kBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Contour rings radiating from the pin — a map, not a plain panel.
            Positioned.fill(
              child: CustomPaint(painter: _ContourPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          hasCity
                              ? Icons.my_location_rounded
                              : Icons.location_searching_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasCity ? 'YOU ARE SHOPPING IN' : 'NO CITY SELECTED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasCity ? current!.trim() : 'Pick your city below',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: hasCity ? 27 : 21,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasCity
                        ? 'Products, stores, delivery fees and riders are all scoped to this city.'
                        : 'Choose a city so prices and delivery fees can be calculated for you.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  if (hasCity) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (home != null && !away)
                          const _HeroPill(
                            icon: Icons.home_rounded,
                            label: 'Your home city',
                            tone: _PillTone.positive,
                          ),
                        if (away)
                          const _HeroPill(
                            icon: Icons.travel_explore_rounded,
                            label: 'Browsing away from home',
                            tone: _PillTone.caution,
                          ),
                        if (home == null)
                          const _HeroPill(
                            icon: Icons.visibility_rounded,
                            label: 'Browsing only',
                            tone: _PillTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PillTone { positive, caution, neutral }

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final _PillTone tone;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _PillTone.positive => const Color(0xFF34D399),
      _PillTone.caution => _kGold,
      _PillTone.neutral => Colors.white,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ordering is only allowed in the registered home municipality — say so here,
/// rather than letting the shopper discover it at checkout.
class _AwayNotice extends StatelessWidget {
  final String home;
  final VoidCallback onGoHome;

  const _AwayNotice({required this.home, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, size: 19, color: Color(0xFFB8860B)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You can browse, but not order here',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Orders are placed in your home city, $home.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home_rounded, size: 15),
                    label: Text('Back to $home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB8860B),
                      side: BorderSide(color: _kGold.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search cities and municipalities',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
          prefixIcon: Icon(Icons.search_rounded,
              size: 19, color: scheme.onSurface.withValues(alpha: 0.45)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17),
                  tooltip: 'Clear search',
                  onPressed: onClear,
                ),
          isDense: true,
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide:
                BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide:
                BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _kBlue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// One selectable municipality. The selected row is filled with the brand
/// gradient so the choice is readable at a glance while scrolling.
class _CityRow extends StatelessWidget {
  final String name;
  final bool selected;
  final bool isHome;
  final VoidCallback onTap;

  const _CityRow({
    required this.name,
    required this.selected,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? null : scheme.surface,
            gradient: selected
                ? const LinearGradient(
                    colors: [_kInk, _kBlue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.onSurface.withValues(alpha: 0.09),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : _kSky.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_city_rounded,
                  size: 18,
                  color: selected ? Colors.white : _kBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
              if (isHome) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFF10B981).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_rounded,
                          size: 11,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        'HOME',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected
                    ? Colors.white
                    : scheme.onSurface.withValues(alpha: 0.22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityListSkeleton extends StatelessWidget {
  const _CityListSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: List.generate(
          6,
          (i) => Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 20),
      child: Column(
        children: [
          Icon(Icons.travel_explore_rounded,
              size: 42, color: scheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            query.isEmpty ? 'No cities available yet' : 'No match for "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Trenda launches city by city. If yours is missing, it is not served yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(
            'Could not load cities',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// What choosing a city actually changes — concrete, not marketing copy.
class _WhyCard extends StatelessWidget {
  const _WhyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: _kBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kSky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    size: 16, color: _kBlue),
              ),
              const SizedBox(width: 10),
              Text(
                'What your city changes',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          line(Icons.storefront_rounded,
              'Which stores and products you can see and buy from.'),
          line(Icons.local_shipping_rounded,
              'The delivery fee, which is set per city and per barangay.'),
          line(Icons.two_wheeler_rounded,
              'Which riders can pick your order up and deliver it.'),
        ],
      ),
    );
  }
}

/// Faint contour rings + a grid, radiating from the hero's pin corner.
class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.88, size.height * 0.16);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.10);
    for (var r = 26.0; r < size.width * 1.15; r += 26) {
      canvas.drawCircle(origin, r, ring);
    }

    final grid = Paint()
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.045);
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    canvas.drawCircle(
      origin,
      4,
      Paint()..color = _kGold.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
