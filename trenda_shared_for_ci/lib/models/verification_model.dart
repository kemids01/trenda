// trenda_shared/lib/models/verification_model.dart
// Vendor verification/onboarding models

/// Vendor verification status
class VendorVerification {
  final String id;
  final String vendorId;
  final String
  status; // not_started, in_progress, pending_review, approved, rejected, changes_requested
  final VerificationProgress progress;
  final BusinessInfo? businessInfo;
  final List<VerificationDocument> documents;
  final BankDetails? bankDetails;
  final String? rejectionReason;
  final List<String>? requestedChanges;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  VendorVerification({
    required this.id,
    required this.vendorId,
    required this.status,
    required this.progress,
    this.businessInfo,
    this.documents = const [],
    this.bankDetails,
    this.rejectionReason,
    this.requestedChanges,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.approvedAt,
  });

  factory VendorVerification.fromJson(Map<String, dynamic> json) {
    // Handle progress which can be either an int (from backend) or a Map
    VerificationProgress progressObj;
    final progressValue = json['progress'];
    if (progressValue is int || progressValue is double) {
      // Backend returns progress as a number (0-100)
      // Clamp to valid range (0-100) to handle any invalid values
      final rawPercent = (progressValue as num).toDouble();
      final percent = (rawPercent / 100).clamp(0.0, 1.0);
      final completedSteps = (percent * 3).round().clamp(0, 3);
      progressObj = VerificationProgress(
        businessInfoComplete: completedSteps >= 1,
        documentsComplete: completedSteps >= 2,
        bankDetailsComplete: completedSteps >= 3,
        completedSteps: completedSteps,
        totalSteps: 3,
      );
    } else if (progressValue is Map<String, dynamic>) {
      progressObj = VerificationProgress.fromJson(progressValue);
    } else {
      progressObj = VerificationProgress();
    }

    return VendorVerification(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      status: json['status'] ?? 'not_started',
      progress: progressObj,
      businessInfo: json['businessInfo'] != null
          ? BusinessInfo.fromJson(json['businessInfo'])
          : null,
      documents: (json['documents'] as List? ?? [])
          .map((d) => VerificationDocument.fromJson(d))
          .toList(),
      bankDetails: json['bankDetails'] != null
          ? BankDetails.fromJson(json['bankDetails'])
          : null,
      rejectionReason: json['rejectionReason'],
      requestedChanges: json['requestedChanges'] != null
          ? List<String>.from(json['requestedChanges'])
          : null,
      assignedTo: json['assignedTo'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'])
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'])
          : null,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending_review';
  bool get needsChanges => status == 'changes_requested';
  bool get isRejected => status == 'rejected';
  bool get canSubmit => progress.isComplete && status != 'pending_review';
}

/// Verification progress tracking
class VerificationProgress {
  final bool businessInfoComplete;
  final bool documentsComplete;
  final bool bankDetailsComplete;
  final int completedSteps;
  final int totalSteps;

  VerificationProgress({
    this.businessInfoComplete = false,
    this.documentsComplete = false,
    this.bankDetailsComplete = false,
    this.completedSteps = 0,
    this.totalSteps = 3,
  });

  factory VerificationProgress.fromJson(Map<String, dynamic> json) {
    final businessComplete =
        json['businessInfoComplete'] ?? json['businessInfo'] ?? false;
    final docsComplete =
        json['documentsComplete'] ?? json['documents'] ?? false;
    final bankComplete =
        json['bankDetailsComplete'] ?? json['bankDetails'] ?? false;

    int completed = 0;
    if (businessComplete) completed++;
    if (docsComplete) completed++;
    if (bankComplete) completed++;

    return VerificationProgress(
      businessInfoComplete: businessComplete,
      documentsComplete: docsComplete,
      bankDetailsComplete: bankComplete,
      completedSteps: json['completedSteps'] ?? completed,
      totalSteps: json['totalSteps'] ?? 3,
    );
  }

  double get progressPercent =>
      totalSteps > 0 ? completedSteps / totalSteps : 0;
  bool get isComplete => completedSteps >= totalSteps;
}

/// Business information for verification
class BusinessInfo {
  final String businessName;
  final String businessType; // sole_proprietor, partnership, corporation
  final String? registrationNumber;
  final String? taxId;
  final String address;
  final String city;
  final String? province;
  final String? postalCode;
  final String phone;
  final String? website;
  final String? description;

  BusinessInfo({
    required this.businessName,
    required this.businessType,
    this.registrationNumber,
    this.taxId,
    required this.address,
    required this.city,
    this.province,
    this.postalCode,
    required this.phone,
    this.website,
    this.description,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      businessName: json['businessName'] ?? json['name'] ?? '',
      businessType: json['businessType'] ?? json['type'] ?? 'sole_proprietor',
      registrationNumber:
          json['registrationNumber'] ?? json['dtiNumber'] ?? json['secNumber'],
      taxId: json['taxId'] ?? json['tin'],
      address: json['address'] ?? json['streetAddress'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? json['state'],
      postalCode: json['postalCode'] ?? json['zipCode'],
      phone: json['phone'] ?? json['contactNumber'] ?? '',
      website: json['website'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'businessType': businessType,
    if (registrationNumber != null) 'registrationNumber': registrationNumber,
    if (taxId != null) 'taxId': taxId,
    'address': address,
    'city': city,
    if (province != null) 'province': province,
    if (postalCode != null) 'postalCode': postalCode,
    'phone': phone,
    if (website != null) 'website': website,
    if (description != null) 'description': description,
  };
}

/// Verification document
class VerificationDocument {
  final String id;
  final String
  type; // id_front, id_back, business_permit, tax_certificate, bank_statement, etc.
  final String? name;
  final String url;
  final String status; // pending, approved, rejected
  final String? rejectionReason;
  final DateTime uploadedAt;
  final DateTime? verifiedAt;

  VerificationDocument({
    required this.id,
    required this.type,
    this.name,
    required this.url,
    required this.status,
    this.rejectionReason,
    required this.uploadedAt,
    this.verifiedAt,
  });

  factory VerificationDocument.fromJson(Map<String, dynamic> json) {
    return VerificationDocument(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? json['documentType'] ?? 'other',
      name: json['name'] ?? json['filename'],
      url: json['url'] ?? json['fileUrl'] ?? '',
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejectionReason'],
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'])
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'])
                : DateTime.now()),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'])
          : null,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';

  String get displayName {
    switch (type) {
      case 'id_front':
        return 'ID (Front)';
      case 'id_back':
        return 'ID (Back)';
      case 'business_permit':
        return 'Business Permit';
      case 'tax_certificate':
        return 'Tax Certificate';
      case 'bank_statement':
        return 'Bank Statement';
      case 'sec_registration':
        return 'SEC Registration';
      case 'dti_registration':
        return 'DTI Registration';
      default:
        return name ?? type;
    }
  }
}

/// Bank details for payouts
class BankDetails {
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? routingNumber;
  final String accountType; // savings, checking
  final bool isVerified;

  BankDetails({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.routingNumber,
    this.accountType = 'savings',
    this.isVerified = false,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      bankName: json['bankName'] ?? json['bank'] ?? '',
      accountName: json['accountName'] ?? json['holderName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      routingNumber: json['routingNumber'] ?? json['branchCode'],
      accountType: json['accountType'] ?? json['type'] ?? 'savings',
      isVerified: json['isVerified'] ?? json['verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'accountName': accountName,
    'accountNumber': accountNumber,
    if (routingNumber != null) 'routingNumber': routingNumber,
    'accountType': accountType,
  };

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }
}

/// Required documents list
class RequiredDocuments {
  static const List<String> individual = ['id_front', 'id_back'];

  static const List<String> soleProprietor = [
    'id_front',
    'id_back',
    'dti_registration',
  ];

  static const List<String> partnership = [
    'id_front',
    'id_back',
    'sec_registration',
    'business_permit',
  ];

  static const List<String> corporation = [
    'id_front',
    'id_back',
    'sec_registration',
    'business_permit',
    'tax_certificate',
  ];

  static List<String> forBusinessType(String type) {
    switch (type) {
      case 'sole_proprietor':
        return soleProprietor;
      case 'partnership':
        return partnership;
      case 'corporation':
        return corporation;
      default:
        return individual;
    }
  }
}
