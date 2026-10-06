import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';

class PsgcLocation {
  final String id;
  final String psgcCode;
  final String name;
  final String level;
  final String? parentCode;

  PsgcLocation({
    required this.id,
    required this.psgcCode,
    required this.name,
    required this.level,
    this.parentCode,
  });

  factory PsgcLocation.fromJson(Map<String, dynamic> json) {
    return PsgcLocation(
      id: json['_id'] ?? '',
      psgcCode: json['psgcCode'] ?? '',
      name: json['name'] ?? '',
      level: json['level'] ?? '',
      parentCode: json['parentCode'],
    );
  }
}

class PsgcLocationState {
  final bool isLoading;
  final String? error;
  final List<PsgcLocation> regions;
  final List<PsgcLocation> provinces;
  final List<PsgcLocation> municipalities;
  final List<PsgcLocation> barangays;
  final String? selectedRegionCode;
  final String? selectedProvinceCode;
  final String? selectedMunicipalityCode;

  PsgcLocationState({
    this.isLoading = false,
    this.error,
    this.regions = const [],
    this.provinces = const [],
    this.municipalities = const [],
    this.barangays = const [],
    this.selectedRegionCode,
    this.selectedProvinceCode,
    this.selectedMunicipalityCode,
  });

  PsgcLocationState copyWith({
    bool? isLoading,
    String? error,
    List<PsgcLocation>? regions,
    List<PsgcLocation>? provinces,
    List<PsgcLocation>? municipalities,
    List<PsgcLocation>? barangays,
    String? selectedRegionCode,
    String? selectedProvinceCode,
    String? selectedMunicipalityCode,
  }) {
    return PsgcLocationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      regions: regions ?? this.regions,
      provinces: provinces ?? this.provinces,
      municipalities: municipalities ?? this.municipalities,
      barangays: barangays ?? this.barangays,
      selectedRegionCode: selectedRegionCode ?? this.selectedRegionCode,
      selectedProvinceCode: selectedProvinceCode ?? this.selectedProvinceCode,
      selectedMunicipalityCode:
          selectedMunicipalityCode ?? this.selectedMunicipalityCode,
    );
  }
}

class PsgcLocationNotifier extends StateNotifier<PsgcLocationState> {
  PsgcLocationNotifier() : super(PsgcLocationState()) {
    loadRegions();
  }

  Future<void> loadRegions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/locations/regions'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final regions = (data['data'] as List)
              .map((r) => PsgcLocation.fromJson(r))
              .toList();
          state = state.copyWith(isLoading: false, regions: regions);
        }
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Failed to load regions');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadProvinces(String regionCode) async {
    state = state.copyWith(
      isLoading: true,
      selectedRegionCode: regionCode,
      provinces: [],
      municipalities: [],
      barangays: [],
      selectedProvinceCode: null,
      selectedMunicipalityCode: null,
    );
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.backendBaseUrl}/api/locations/provinces/$regionCode'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final rawData = data['data'] as List;
          List<PsgcLocation> provinces;
          if (rawData.isNotEmpty && rawData[0] is String) {
            provinces = rawData
                .map((name) => PsgcLocation(
                      id: '',
                      psgcCode: name.toString(),
                      name: name.toString(),
                      level: 'province',
                    ))
                .toList();
          } else {
            provinces = rawData.map((p) => PsgcLocation.fromJson(p)).toList();
          }
          state = state.copyWith(isLoading: false, provinces: provinces);
        }
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Failed to load provinces');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMunicipalities(String provinceCode) async {
    state = state.copyWith(
      isLoading: true,
      selectedProvinceCode: provinceCode,
      municipalities: [],
      barangays: [],
      selectedMunicipalityCode: null,
    );
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.backendBaseUrl}/api/locations/municipalities/$provinceCode'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final rawData = data['data'] as List;
          List<PsgcLocation> municipalities;
          if (rawData.isNotEmpty && rawData[0] is String) {
            municipalities = rawData
                .map((name) => PsgcLocation(
                      id: '',
                      psgcCode: name.toString(),
                      name: name.toString(),
                      level: 'municipality',
                    ))
                .toList();
          } else {
            municipalities =
                rawData.map((m) => PsgcLocation.fromJson(m)).toList();
          }
          state =
              state.copyWith(isLoading: false, municipalities: municipalities);
        }
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to load municipalities');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBarangays(String municipalityCode) async {
    state = state.copyWith(
      isLoading: true,
      selectedMunicipalityCode: municipalityCode,
      barangays: [],
    );
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConfig.backendBaseUrl}/api/locations/barangays/$municipalityCode'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final barangays = (data['data'] as List)
              .map((b) => PsgcLocation.fromJson(b))
              .toList();
          state = state.copyWith(isLoading: false, barangays: barangays);
        }
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Failed to load barangays');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = PsgcLocationState();
    loadRegions();
  }
}

final installmentPsgcProvider =
    StateNotifierProvider<PsgcLocationNotifier, PsgcLocationState>((ref) {
  return PsgcLocationNotifier();
});
