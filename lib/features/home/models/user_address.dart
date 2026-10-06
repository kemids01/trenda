//lib/features/home/models/user_address.dart

/// Location source types for addresses
enum LocationType { manual, gps, map }

/// ----------------------
/// ADDRESS MODEL
/// ----------------------
class UserAddress {
  final String id;
  final String label;
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final String region;
  final String? province;
  final String? barangay;
  final String? houseNumber;
  final String? building;
  final String? landmark;
  final String? additionalInfo;
  final LocationType locationType; // ✅ Track how address was added
  final double? latitude;
  final double? longitude;

  UserAddress({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.region,
    this.province,
    this.barangay,
    this.houseNumber,
    this.building,
    this.landmark,
    this.additionalInfo,
    this.locationType = LocationType.manual,
    this.latitude,
    this.longitude,
  });

  // Construct from backend JSON
  factory UserAddress.fromJson(Map<String, dynamic> json) => UserAddress(
        id: json['id'] ?? json['_id'] ?? '',
        label: json['label'] ?? '',
        street: json['street'] ?? '',
        city: json['city'] ?? '',
        postalCode: json['postalCode'] ?? json['zip'] ?? '',
        country: json['country'] ?? '',
        region: json['region'] ?? '',
        province: json['province'],
        barangay: json['barangay'],
        houseNumber: json['houseNumber'],
        building: json['building'],
        landmark: json['landmark'],
        additionalInfo: json['additionalInfo'],
        locationType: _parseLocationType(json['locationType']),
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
      );

  static LocationType _parseLocationType(dynamic type) {
    if (type == 'gps') return LocationType.gps;
    if (type == 'map') return LocationType.map;
    return LocationType.manual;
  }

  // To send to backend
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'street': street,
        'city': city,
        'postalCode': postalCode,
        'country': country,
        'region': region,
        'province': province,
        'barangay': barangay,
        'houseNumber': houseNumber,
        'building': building,
        'landmark': landmark,
        'additionalInfo': additionalInfo,
        'locationType': locationType.name,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// 🔹 Add this method for local optimistic updates
  UserAddress copyWith({
    String? id,
    String? label,
    String? street,
    String? city,
    String? postalCode,
    String? country,
    String? region,
    String? province,
    String? barangay,
    String? houseNumber,
    String? building,
    String? landmark,
    String? additionalInfo,
    LocationType? locationType,
    double? latitude,
    double? longitude,
  }) {
    return UserAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      street: street ?? this.street,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      region: region ?? this.region,
      province: province ?? this.province,
      barangay: barangay ?? this.barangay,
      houseNumber: houseNumber ?? this.houseNumber,
      building: building ?? this.building,
      landmark: landmark ?? this.landmark,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      locationType: locationType ?? this.locationType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
