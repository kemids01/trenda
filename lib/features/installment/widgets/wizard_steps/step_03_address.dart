import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/application_form_provider.dart';
import '../../providers/psgc_location_provider.dart';
import 'form_helpers.dart';

class Step05Address extends ConsumerStatefulWidget {
  const Step05Address({super.key});

  @override
  ConsumerState<Step05Address> createState() => _Step05AddressState();
}

class _Step05AddressState extends ConsumerState<Step05Address> {
  late TextEditingController _streetCtrl;
  late TextEditingController _zipCtrl;
  double? _lat;
  double? _lng;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    final address = ref.read(installmentFormProvider).formData['addressInfo']
            as Map<String, dynamic>? ??
        {};

    _streetCtrl = TextEditingController(text: address['street']);
    _zipCtrl = TextEditingController(text: address['zipCode']);
    _lat = address['gpsLatitude'] as double?;
    _lng = address['gpsLongitude'] as double?;

    _streetCtrl.addListener(() => _update('street', _streetCtrl.text));
    _zipCtrl.addListener(() => _update('zipCode', _zipCtrl.text));

    // Pre-load regions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final psgc = ref.read(installmentPsgcProvider);
      if (psgc.regions.isEmpty) {
        ref.read(installmentPsgcProvider.notifier).loadRegions();
      }
    });
  }

  void _update(String key, dynamic value) {
    ref
        .read(installmentFormProvider.notifier)
        .updateSection('addressInfo', {key: value});
  }

  Future<void> _getGPS() async {
    setState(() => _gpsLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _gpsLoading = false;
      });
      _update('gpsLatitude', position.latitude);
      _update('gpsLongitude', position.longitude);
    } catch (e) {
      setState(() => _gpsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final psgc = ref.watch(installmentPsgcProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Current Address', Icons.location_on_outlined,
            subtitle: 'PSGC-based Philippine address'),

        // PSGC Cascading Dropdowns
        formCard(children: [
          // Region
          DropdownButtonFormField<String>(
            value: psgc.selectedRegionCode,
            decoration: compactInput('Region', icon: Icons.map_outlined),
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: psgc.regions
                .map((r) => DropdownMenuItem(
                    value: r.psgcCode,
                    child: Text(r.name, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(installmentPsgcProvider.notifier).loadProvinces(val);
                final regionName = psgc.regions
                    .firstWhere((r) => r.psgcCode == val,
                        orElse: () => PsgcLocation(
                            id: '', psgcCode: '', name: '', level: ''))
                    .name;
                _update('region', regionName);
              }
            },
          ),
          fieldGap,

          // Province
          DropdownButtonFormField<String>(
            value: psgc.selectedProvinceCode,
            decoration: compactInput('Province'),
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: psgc.provinces
                .map((p) => DropdownMenuItem(
                    value: p.psgcCode,
                    child: Text(p.name, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: psgc.provinces.isEmpty
                ? null
                : (val) {
                    if (val != null) {
                      ref
                          .read(installmentPsgcProvider.notifier)
                          .loadMunicipalities(val);
                      final name = psgc.provinces
                          .firstWhere((p) => p.psgcCode == val,
                              orElse: () => PsgcLocation(
                                  id: '', psgcCode: '', name: '', level: ''))
                          .name;
                      _update('province', name);
                    }
                  },
          ),
          fieldGap,

          // Municipality
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: psgc.selectedMunicipalityCode,
                  decoration: compactInput('City / Municipality'),
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: psgc.municipalities
                      .map((m) => DropdownMenuItem(
                          value: m.psgcCode,
                          child: Text(m.name,
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: psgc.municipalities.isEmpty
                      ? null
                      : (val) {
                          if (val != null) {
                            ref
                                .read(installmentPsgcProvider.notifier)
                                .loadBarangays(val);
                            final name = psgc.municipalities
                                .firstWhere((m) => m.psgcCode == val,
                                    orElse: () => PsgcLocation(
                                        id: '',
                                        psgcCode: '',
                                        name: '',
                                        level: ''))
                                .name;
                            _update('municipality', name);
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _zipCtrl,
                  keyboardType: TextInputType.number,
                  decoration: compactInput('Zip Code'),
                ),
              ),
            ],
          ),
          fieldGap,

          // Barangay
          DropdownButtonFormField<String>(
            value: null,
            decoration:
                compactInput('Barangay', icon: Icons.holiday_village_outlined),
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: psgc.barangays
                .map((b) => DropdownMenuItem(
                    value: b.name,
                    child: Text(b.name, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: psgc.barangays.isEmpty
                ? null
                : (val) {
                    if (val != null) _update('barangay', val);
                  },
          ),
          if (psgc.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ]),
        const SizedBox(height: 10),

        // Street + GPS
        formCard(children: [
          TextFormField(
            controller: _streetCtrl,
            decoration: compactInput('House # / Street / Subdivision',
                icon: Icons.home_outlined),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gpsLoading ? null : _getGPS,
                  icon: _gpsLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _lat != null ? Icons.check_circle : Icons.gps_fixed,
                          size: 16,
                          color: _lat != null ? Colors.green : null),
                  label: Text(
                    _lat != null
                        ? 'GPS: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                        : 'Get GPS Location',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(
                      color: _lat != null
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
