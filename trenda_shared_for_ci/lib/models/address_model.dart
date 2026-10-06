// trenda_shared/lib/models/address_model.dart

class AddressModel {
  final String? region;
  final String? province;
  final String? cityMunicipality;
  final String? barangay;
  final String? street;
  final String? houseNumber;
  final String? building;
  final String? landmark;
  final String? additionalInfo;
  final String? postalCode;
  final String? country;
  final List<double>? coordinates; // [longitude, latitude]
  final String? fullAddress;
  final bool isComplete;

  AddressModel({
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
    this.country,
    this.coordinates,
    this.fullAddress,
    this.isComplete = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      region: json['region'] as String?,
      province: json['province'] as String?,
      cityMunicipality: json['cityMunicipality'] as String?,
      barangay: json['barangay'] as String?,
      street: json['street'] as String?,
      houseNumber: json['houseNumber'] as String?,
      building: json['building'] as String?,
      landmark: json['landmark'] as String?,
      additionalInfo: json['additionalInfo'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String? ?? 'Philippines',
      coordinates: json['coordinates'] != null
          ? List<double>.from(json['coordinates'])
          : null,
      fullAddress: json['fullAddress'] as String?,
      isComplete: json['isComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'region': region,
      'province': province,
      'cityMunicipality': cityMunicipality,
      'barangay': barangay,
      'street': street,
      'houseNumber': houseNumber,
      'building': building,
      'landmark': landmark,
      'additionalInfo': additionalInfo,
      'postalCode': postalCode,
      'country': country ?? 'Philippines',
      'coordinates': coordinates,
      'fullAddress': fullAddress,
      'isComplete': isComplete,
    };
  }

  AddressModel copyWith({
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
    String? country,
    List<double>? coordinates,
    String? fullAddress,
    bool? isComplete,
  }) {
    return AddressModel(
      region: region ?? this.region,
      province: province ?? this.province,
      cityMunicipality: cityMunicipality ?? this.cityMunicipality,
      barangay: barangay ?? this.barangay,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      building: building ?? this.building,
      landmark: landmark ?? this.landmark,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      coordinates: coordinates ?? this.coordinates,
      fullAddress: fullAddress ?? this.fullAddress,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Get formatted address string for display
  String getDisplayAddress() {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      return fullAddress!;
    }

    final parts = <String>[];
    if (houseNumber != null) parts.add(houseNumber!);
    if (building != null) parts.add(building!);
    if (street != null) parts.add(street!);
    if (barangay != null) parts.add('Brgy. $barangay');
    if (cityMunicipality != null) parts.add(cityMunicipality!);
    if (province != null) parts.add(province!);
    if (region != null) parts.add(region!);

    return parts.join(', ');
  }

  /// Check if minimum required fields are filled
  bool get hasMinimumInfo {
    return region != null &&
        province != null &&
        cityMunicipality != null &&
        barangay != null;
  }

  @override
  String toString() => getDisplayAddress();
}
