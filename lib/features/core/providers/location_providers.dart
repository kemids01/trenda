import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/trenda_shared.dart' hide UserAddress;
import '../../home/models/user_address.dart';
import '../data/deliverable_repository.dart';

// Repository Provider
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

// Deliverable-cities repository (served ∪ neighbour towns) — ADDRESS pickers only.
final deliverableRepositoryProvider = Provider((ref) => DeliverableRepository());

/// Cities a customer may live in (served ∪ neighbours) — ADDRESS pickers only.
/// The BROWSE filter (city pill, /city page) stays on availableMunicipalitiesProvider.
final deliverableMunicipalitiesProvider = FutureProvider<List<MunicipalityModel>>(
    (ref) => ref.watch(deliverableRepositoryProvider).municipalities());

// Regions Provider
final regionsProvider = FutureProvider<List<PhilippineRegion>>((ref) async {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getRegions();
});

// Provinces Provider (depends on selected region)
final provincesProvider =
    FutureProvider.family<List<String>, String?>((ref, region) async {
  if (region == null || region.isEmpty) {
    return [];
  }

  final repo = ref.watch(locationRepositoryProvider);
  return repo.getProvinces(region);
});

// Cities Provider (depends on selected province)
final citiesProvider = FutureProvider.family<List<CityMunicipality>, String?>(
    (ref, province) async {
  if (province == null || province.isEmpty) {
    return [];
  }

  final repo = ref.watch(locationRepositoryProvider);
  return repo.getCities(province);
});

// Barangays Provider (depends on selected city) — used by ADDRESS pickers only
// (saved-address form, checkout GPS confirm). Served city → its active barangays
// (same as before); a neighbour town → its full PSGC barangay list.
final barangaysProvider =
    FutureProvider.family<List<String>, String?>((ref, city) async {
  if (city == null || city.isEmpty) {
    return [];
  }

  return ref.watch(deliverableRepositoryProvider).barangays(city);
});

// Address Form State Provider
class AddressFormState {
  final String? region;
  final String? province;
  final String? cityMunicipality;
  final String? barangay;
  final String? street;
  final String? houseNumber;
  final String? building;
  final String? landmark;
  final String? additionalInfo; // Notes
  final String? postalCode;
  final String? label;
  // ✅ GPS coordinates from map picker or GPS
  final double? latitude;
  final double? longitude;
  final LocationType locationType; // ✅ Track how location was captured

  AddressFormState({
    this.region,
    this.province,
    this.cityMunicipality,
    this.barangay,
    this.street,
    this.houseNumber,
    this.building,
    this.landmark,
    this.additionalInfo,
    this.postalCode,
    this.label,
    this.latitude,
    this.longitude,
    this.locationType = LocationType.manual,
  });

  AddressFormState copyWith({
    String? region,
    String? province,
    String? cityMunicipality,
    String? barangay,
    String? street,
    String? houseNumber,
    String? building,
    String? landmark,
    String? additionalInfo,
    String? postalCode,
    String? label,
    double? latitude,
    double? longitude,
    LocationType? locationType,
    bool clearProvince = false,
    bool clearCity = false,
    bool clearBarangay = false,
  }) {
    return AddressFormState(
      region: region ?? this.region,
      province: clearProvince ? null : (province ?? this.province),
      cityMunicipality:
          clearCity ? null : (cityMunicipality ?? this.cityMunicipality),
      barangay: clearBarangay ? null : (barangay ?? this.barangay),
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      building: building ?? this.building,
      landmark: landmark ?? this.landmark,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      postalCode: postalCode ?? this.postalCode,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationType: locationType ?? this.locationType,
    );
  }

  UserAddress toUserAddress(String id) {
    return UserAddress(
      id: id,
      label: label ?? 'Home',
      street: street ?? '',
      city: cityMunicipality ?? '',
      postalCode: postalCode ?? '',
      country: 'Philippines',
      region: region ?? '',
      province: province,
      barangay: barangay,
      houseNumber: houseNumber,
      building: building,
      landmark: landmark,
      additionalInfo: additionalInfo,
      locationType: locationType, // ✅ Use tracked locationType
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory AddressFormState.fromUserAddress(UserAddress? address) {
    if (address == null) return AddressFormState();

    return AddressFormState(
      region: address.region,
      province: address.province,
      cityMunicipality: address.city,
      barangay: address.barangay,
      street: address.street,
      houseNumber: address.houseNumber,
      building: address.building,
      landmark: address.landmark,
      additionalInfo: address.additionalInfo,
      postalCode: address.postalCode,
      label: address.label,
      latitude: address.latitude,
      longitude: address.longitude,
      locationType: address.locationType,
    );
  }

  bool get isValid {
    return region != null &&
        province != null &&
        cityMunicipality != null &&
        barangay != null &&
        street != null &&
        street!.isNotEmpty &&
        houseNumber != null &&
        houseNumber!.isNotEmpty &&
        latitude != null &&
        longitude != null;
  }
}

class AddressFormNotifier extends StateNotifier<AddressFormState> {
  AddressFormNotifier() : super(AddressFormState());

  void setRegion(String region) {
    state = state.copyWith(
      region: region,
      clearProvince: true,
      clearCity: true,
      clearBarangay: true,
    );
  }

  void setProvince(String province) {
    state = state.copyWith(
      province: province,
      clearCity: true,
      clearBarangay: true,
    );
  }

  void setCityMunicipality(String city) {
    state = state.copyWith(
      cityMunicipality: city,
      clearBarangay: true,
    );
  }

  void setBarangay(String barangay) {
    state = state.copyWith(barangay: barangay);
  }

  void setStreet(String street) {
    state = state.copyWith(street: street);
  }

  void setHouseNumber(String houseNumber) {
    state = state.copyWith(houseNumber: houseNumber);
  }

  void setLabel(String label) {
    state = state.copyWith(label: label);
  }

  void setBuilding(String building) {
    state = state.copyWith(building: building);
  }

  void setLandmark(String landmark) {
    state = state.copyWith(landmark: landmark);
  }

  void setAdditionalInfo(String info) {
    state = state.copyWith(additionalInfo: info);
  }

  void setPostalCode(String postalCode) {
    state = state.copyWith(postalCode: postalCode);
  }

  void loadAddress(UserAddress address) {
    state = AddressFormState.fromUserAddress(address);
  }

  // Method to auto-populate from profile data if needed
  void loadFromProfile(UserAddress address) {
    loadAddress(address);
  }

  // ✅ Convenience method for map picker integration
  void updateStreet(String street) {
    setStreet(street);
  }

  // ✅ Update coordinates from map picker
  void updateCoordinates(double lat, double lng) {
    state = state.copyWith(
      latitude: lat,
      longitude: lng,
    );
  }

  // ✅ Set location type (gps, map, or manual)
  void setLocationType(LocationType locationType) {
    state = state.copyWith(locationType: locationType);
  }

  void reset() {
    state = AddressFormState();
  }
}

final addressFormProvider =
    StateNotifierProvider.autoDispose<AddressFormNotifier, AddressFormState>(
  (ref) => AddressFormNotifier(),
);
