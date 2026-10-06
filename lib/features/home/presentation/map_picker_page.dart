// lib/features/home/presentation/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trenda_shared/trenda_shared.dart' show GeoService, Debouncer;
import '../../../design_system/design_system.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialQuery;

  const MapPickerPage({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.initialQuery,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer =
      Debouncer(delay: const Duration(milliseconds: 500));

  late LatLng _selectedLocation;
  String? _selectedAddress;
  bool _isSearching = false;
  List<_SearchResult> _searchResults = [];

  // Parsed address components from geocoding
  String? _region;
  String? _province;
  String? _city;
  String? _barangay;
  String? _street;

  // Pre-GPS camera seed only — overridden by device GPS on open
  // (see _goToCurrentLocation in initState). Not a data-scoping default.
  static const _fallbackCamera = LatLng(17.6132, 121.7270);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _fallbackCamera;
    _selectedAddress = widget.initialAddress;

    if (widget.initialLocation == null && widget.initialQuery == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToCurrentLocation();
      });
    } else if (widget.initialLocation == null && widget.initialQuery != null) {
      _performInitialSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: _selectedAddress != null ? _confirmSelection : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          AllowRapidTaps(
              child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              // OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trenda.frontend',
              ),
              // Selected location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.error,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          )),

          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.borderRadiusMD,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.overlayLight,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: AppSpacing.paddingMD,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.borderRadiusMD,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.overlayLight,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(result.name),
                          subtitle: Text(
                            result.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Selected address card
          if (_selectedAddress != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.borderRadiusMD,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.overlayLight,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.primary),
                        AppSpacing.horizontalSM,
                        Expanded(
                          child: Text(
                            'Selected Location',
                            style: AppTypography.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalXS,
                    Text(
                      _selectedAddress!,
                      style: AppTypography.bodyMedium,
                    ),
                    AppSpacing.verticalSM,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmSelection,
                        child: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Current location FAB
          Positioned(
            bottom: _selectedAddress != null ? 180 : 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _goToCurrentLocation,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = 'Lat: ${point.latitude.toStringAsFixed(6)}, '
          'Lng: ${point.longitude.toStringAsFixed(6)}';
    });
    _reverseGeocode(point);
  }

  void _onSearchChanged(String query) {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    // Use debouncer to avoid too many API calls
    _searchDebouncer.call(() => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      // Use GeoService with built-in caching and rate limiting
      final results = await GeoService.search(
        query,
        countryCode: 'ph',
        limit: 5,
      );

      setState(() {
        _searchResults = results.map((location) {
          return _SearchResult(
            name: location.displayName?.split(',').first ?? 'Unknown',
            address: location.displayName ?? '',
            location: LatLng(location.latitude, location.longitude),
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _selectedLocation = result.location;
      _selectedAddress = result.address;
      _searchResults = [];
      _searchController.text = result.name;
    });
    _mapController.move(result.location, 16);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      // Use GeoService with built-in caching
      final result = await GeoService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (result != null && mounted) {
        final components = result.components;
        setState(() {
          _selectedAddress = result.displayName ??
              (components?.formattedAddress ?? "Unknown location");

          // ✅ Extract address components for form population
          if (components != null) {
            _region = components.state ?? components.region;
            _province = components.county;
            _city =
                components.city ?? components.municipality ?? components.town;
            _barangay = components.suburb ?? components.village;
            _street = components.road;
          }
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      setState(() {
        _selectedAddress = 'Lat: ${point.latitude.toStringAsFixed(6)}, '
            'Lng: ${point.longitude.toStringAsFixed(6)}';
      });
    }
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
      }
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting current location...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      _mapController.move(latLng, 16);
      setState(() {
        _selectedLocation = latLng;
        _selectedAddress = 'Current Location\n'
            'Lat: ${latLng.latitude.toStringAsFixed(6)}, '
            'Lng: ${latLng.longitude.toStringAsFixed(6)}';
      });
      // Optionally reverse geocode here if API available
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _confirmSelection() {
    Navigator.pop(
        context,
        MapPickerResult(
          location: _selectedLocation,
          address: _selectedAddress ?? '',
          // ✅ Include parsed address components
          region: _region,
          province: _province,
          city: _city,
          barangay: _barangay,
          street: _street,
        ));
  }

  Future<void> _performInitialSearch(String query) async {
    _searchController.text = query;
    await _performSearch(query);
    if (_searchResults.isNotEmpty) {
      final firstResult = _searchResults.first;
      _mapController.move(firstResult.location, 15);
      _selectSearchResult(firstResult);
    }
  }
}

class _SearchResult {
  final String name;
  final String address;
  final LatLng location;

  _SearchResult({
    required this.name,
    required this.address,
    required this.location,
  });
}

class MapPickerResult {
  final LatLng location;
  final String address;
  // Parsed address components for form population
  final String? region;
  final String? province;
  final String? city;
  final String? barangay;
  final String? street;

  MapPickerResult({
    required this.location,
    required this.address,
    this.region,
    this.province,
    this.city,
    this.barangay,
    this.street,
  });
}
