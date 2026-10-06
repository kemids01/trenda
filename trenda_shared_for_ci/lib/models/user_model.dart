// trenda_shared/lib/models/user_model.dart - FIXED

/// User address model for profile
class UserAddress {
  final String? street;
  final String? city;
  final String? province;
  final String? barangay;
  final String? postalCode;

  UserAddress({
    this.street,
    this.city,
    this.province,
    this.barangay,
    this.postalCode,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      province: json['province']?.toString(),
      barangay: json['barangay']?.toString(),
      postalCode: json['postalCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'street': street,
    'city': city,
    'province': province,
    'barangay': barangay,
    'postalCode': postalCode,
  };
}

class UserModel {
  final String id;
  final String? firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final List<String> roles;
  final String
  status; // ✅ ADDED: active, suspended, deleted, pending_verification
  final bool isVerified;
  final VendorProfile? vendorProfile;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ✅ ADDED: Suspension info
  final String? suspensionReason;
  final DateTime? suspendedAt;

  // ✅ ADDED: Profile info
  final DateTime? birthday;
  final UserAddress? address;

  UserModel({
    required this.id,
    this.firebaseUid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phone,
    List<String>? roles,
    this.status = 'active', // ✅ ADDED with default
    this.isVerified = false,
    this.vendorProfile,
    this.createdAt,
    this.updatedAt,
    this.suspensionReason,
    this.suspendedAt,
    this.birthday,
    this.address,
  }) : roles = roles ?? ['customer'];

  // Helper to get primary role
  String get role => roles.isNotEmpty ? roles.first : 'customer';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      firebaseUid: json['firebaseUid']?.toString(),
      email: json['email']?.toString(),
      displayName: json['name']?.toString() ?? json['displayName']?.toString(),
      photoUrl: json['photoUrl']?.toString() ?? json['photoURL']?.toString(),
      phone: json['phone']?.toString(),
      roles:
          (json['roles'] as List?)?.map((e) => e.toString()).toList() ??
          [json['role']?.toString() ?? 'customer'],
      status: json['status']?.toString() ?? 'active', // ✅ ADDED
      isVerified: json['isVerified'] == true,
      vendorProfile: json['vendorProfile'] != null
          ? VendorProfile.fromJson(json['vendorProfile'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      suspensionReason: json['suspensionReason']?.toString(), // ✅ ADDED
      suspendedAt: json['suspendedAt'] != null
          ? DateTime.tryParse(json['suspendedAt'])
          : null,
      birthday: json['birthday'] != null
          ? DateTime.tryParse(json['birthday'])
          : null,
      address: json['address'] != null
          ? UserAddress.fromJson(json['address'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firebaseUid': firebaseUid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'phone': phone,
    'roles': roles,
    'status': status, // ✅ ADDED
    'isVerified': isVerified,
    'vendorProfile': vendorProfile?.toJson(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'suspensionReason': suspensionReason,
    'suspendedAt': suspendedAt?.toIso8601String(),
    'birthday': birthday?.toIso8601String(),
    'address': address?.toJson(),
  };

  UserModel copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phone,
    List<String>? roles,
    String? status, // ✅ ADDED
    bool? isVerified,
    VendorProfile? vendorProfile,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? suspensionReason,
    DateTime? suspendedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      status: status ?? this.status, // ✅ ADDED
      isVerified: isVerified ?? this.isVerified,
      vendorProfile: vendorProfile ?? this.vendorProfile,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      suspendedAt: suspendedAt ?? this.suspendedAt,
    );
  }
}

// ✅ FIXED: VendorProfile with verification field
class VendorProfile {
  final String? storeName;
  final String? storeDescription;
  final String? storeLogo;
  final bool verified;
  final double rating;
  final int totalSales;

  // ✅ ADDED: Extended verification block
  final VendorVerification? verification;

  VendorProfile({
    this.storeName,
    this.storeDescription,
    this.storeLogo,
    this.verified = false,
    this.rating = 0,
    this.totalSales = 0,
    this.verification, // ✅ ADDED
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      storeName: json['storeName']?.toString(),
      storeDescription: json['storeDescription']?.toString(),
      storeLogo: json['storeLogo']?.toString(),
      verified: json['verified'] == true,
      rating: (json['rating'] ?? 0).toDouble(),
      totalSales: json['totalSales'] ?? 0,
      verification:
          json['verification'] !=
              null // ✅ ADDED
          ? VendorVerification.fromJson(json['verification'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'storeDescription': storeDescription,
    'storeLogo': storeLogo,
    'verified': verified,
    'rating': rating,
    'totalSales': totalSales,
    'verification': verification?.toJson(), // ✅ ADDED
  };
}

// ✅ NEW: VendorVerification model
class VendorVerification {
  final String status; // unverified, pending, verified, premium
  final String? badge;
  final List<String> documents;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  VendorVerification({
    required this.status,
    this.badge,
    this.documents = const [],
    this.submittedAt,
    this.verifiedAt,
  });

  factory VendorVerification.fromJson(Map<String, dynamic> json) {
    return VendorVerification(
      status: json['status']?.toString() ?? 'unverified',
      badge: json['badge']?.toString(),
      documents:
          (json['documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'])
          : null,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'badge': badge,
    'documents': documents,
    'submittedAt': submittedAt?.toIso8601String(),
    'verifiedAt': verifiedAt?.toIso8601String(),
  };
}
