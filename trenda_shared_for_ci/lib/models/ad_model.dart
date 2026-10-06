import 'map_pin.dart';

class AdModel {
  final String id;
  final String title;
  final String businessName;
  final String? description;
  final String? contact;
  final Map<String, String> socialLinks;
  final List<String> productNames;
  final List<String> photos;

  /// Ads & Services showcase: full-screen pages a shopper swipes through after
  /// tapping this ad in a Shop-tab carousel. Empty when the advertiser has not
  /// bought one, or the admin has not switched it on — either way the tap falls
  /// back to the ordinary ad details page.
  final List<String> showcasePages;

  /// Ads & Services "See all" page: one tall 9:16 creative (1080×1920), shown
  /// uncropped there. Null on most ads — the page then uses the first card photo.
  final String? seeAllImage;

  /// The Ads & Services BAND card's square creative (1080×1080). Null = the
  /// card falls back to [photos].first — use [carouselCardImage].
  final String? carouselImage;

  /// What the band card draws: the square [carouselImage] when set, else the
  /// first photo (empty string when there is none).
  String get carouselCardImage =>
      carouselImage ?? (photos.isNotEmpty ? photos.first : '');

  /// Where the advertised business is, when the admin pinned one. Null otherwise —
  /// which is most ads, so every reader must treat null as ordinary.
  final MapPin? location;

  /// Which Shop-tab carousel — and which customer page — this ad belongs to:
  /// `'vendor'` or `'service'`.
  ///
  /// ⚠️ Ads created before `Ad.kind` existed carry no value, and they ARE
  /// vendor ads. An absent field must read as `'vendor'`; treating it as "not
  /// vendor" hides every ad sold before 2026-09-14 from the Ads page.
  final String kind;

  final String ownerId;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerDisplayName;
  final String? ownerPhotoUrl;

  // Multi-location targeting
  final List<String> municipalities;

  // ✅ NEW: Status & Approval
  final String status; // draft, pending, approved, rejected, expired
  final AdPayment payment;
  final AdApproval? approval;
  final int duration;
  final int? durationDays;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? expiresAt;
  final bool isActive;
  final bool featured;
  final int priority;
  final AdAnalytics analytics;

  // Action (Store Link, Product, URL)
  final Map<String, dynamic>? action;

  // B2B: Target audience for ad visibility
  final String targetAudience; // 'consumer' or 'vendor'

  // Official Trenda Ads support
  final String ownerType; // 'vendor', 'supplier', 'guest', 'official'
  final List<String> targetApps; // ['frontend', 'vendor', 'supplier']
  final String? officialBadgeText; // e.g. 'Trenda Official'

  final bool isWaitlisted;
  final int? waitlistPosition;
  final DateTime? waitlistAddedAt;

  // Budget Caps
  final AdBudget? budgets;

  final DateTime createdAt;
  final DateTime updatedAt;

  AdModel({
    required this.id,
    required this.title,
    required this.businessName,
    this.description,
    this.contact,
    Map<String, String>? socialLinks,
    List<String>? productNames,
    List<String>? photos,
    List<String>? showcasePages,
    this.seeAllImage,
    this.carouselImage,
    this.location,
    this.kind = 'vendor',
    required this.ownerId,
    this.ownerName,
    this.ownerEmail,
    this.ownerDisplayName,
    this.ownerPhotoUrl,
    List<String>? municipalities,
    this.status = 'draft',
    AdPayment? payment,
    this.approval,
    this.duration = 30,
    this.durationDays,
    this.startDate,
    this.endDate,
    this.expiresAt,
    this.isActive = false,
    this.featured = false,
    this.priority = 0,
    AdAnalytics? analytics,
    this.action,
    this.targetAudience = 'consumer',
    this.ownerType = 'vendor',
    List<String>? targetApps,
    this.officialBadgeText,
    this.isWaitlisted = false,
    this.waitlistPosition,
    this.waitlistAddedAt,
    this.budgets,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : socialLinks = socialLinks ?? {},
       productNames = productNames ?? [],
       photos = photos ?? [],
       showcasePages = showcasePages ?? [],
       municipalities = municipalities ?? [],
       targetApps = targetApps ?? [],
       payment = payment ?? AdPayment(),
       analytics = analytics ?? AdAnalytics(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Days remaining until expiry
  int? get daysRemaining {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isOfficial => ownerType == 'official';

  factory AdModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final social = <String, String>{};

    if (json['socialLinks'] is Map) {
      (json['socialLinks'] as Map).forEach((k, v) {
        if (v != null) social[k.toString()] = v.toString();
      });
    }

    return AdModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      description: json['description']?.toString(),
      contact: json['contact']?.toString(),
      socialLinks: social,
      productNames:
          (json['productNames'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      photos:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      // Only a switched-on showcase reaches the app; a half-built one (pages
      // uploaded, toggle off) must behave exactly like no showcase at all.
      showcasePages: _showcasePagesFrom(json['showcase']),
      seeAllImage: _nonBlankString(json['seeAllImage']),
      carouselImage: _nonBlankString(json['carouselImage']),
      location: MapPin.fromJson(
        json['location'] is Map ? Map<String, dynamic>.from(json['location'] as Map) : null,
      ),
      // Absent, null or unrecognised all mean 'vendor' — see the field.
      kind: json['kind']?.toString() == 'service' ? 'service' : 'vendor',
      municipalities:
          (json['municipalities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ownerId: owner is Map
          ? (owner['_id']?.toString() ?? owner['firebaseUid']?.toString() ?? '')
          : (json['owner']?.toString() ?? ''),
      ownerName:
          json['ownerName']?.toString() ??
          (owner is Map ? owner['name']?.toString() : null),
      ownerEmail:
          json['ownerEmail']?.toString() ??
          (owner is Map ? owner['email']?.toString() : null),
      ownerDisplayName: owner is Map ? owner['displayName']?.toString() : null,
      ownerPhotoUrl: owner is Map ? owner['photoURL']?.toString() : null,
      status: json['status']?.toString() ?? 'draft',
      payment: json['payment'] != null
          ? AdPayment.fromJson(json['payment'])
          : AdPayment(),
      approval: json['approval'] != null
          ? AdApproval.fromJson(json['approval'])
          : null,
      duration: json['duration'] ?? 30,
      durationDays: json['durationDays'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      isActive: json['isActive'] ?? false,
      featured: json['featured'] ?? false,
      priority: json['priority'] ?? 0,
      analytics: json['analytics'] != null
          ? AdAnalytics.fromJson(json['analytics'])
          : AdAnalytics(),
      action: json['action'],
      targetAudience: json['targetAudience']?.toString() ?? 'consumer',
      ownerType: json['ownerType']?.toString() ?? 'vendor',
      targetApps: (json['targetApps'] as List?)?.map((e) => e.toString()).toList() ?? [],
      officialBadgeText: json['officialAdMeta'] is Map
          ? json['officialAdMeta']['badgeText']?.toString()
          : null,
      isWaitlisted: json['waitlist'] is Map
          ? (json['waitlist']['isWaitlisted'] ?? false)
          : false,
      waitlistPosition: json['waitlist'] is Map
          ? json['waitlist']['position']
          : null,
      waitlistAddedAt:
          json['waitlist'] is Map && json['waitlist']['addedAt'] != null
          ? DateTime.parse(json['waitlist']['addedAt'])
          : null,
      budgets: json['budgets'] != null
          ? AdBudget.fromJson(json['budgets'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJsonForCreate() => {
    'title': title,
    'businessName': businessName,
    'description': description ?? '',
    'contact': contact ?? '',
    'socialLinks': socialLinks,
    'productNames': productNames,
    'municipalities': municipalities,
    'ownerId': ownerId,
    'duration': duration,
    'durationDays': durationDays,
    'startDate': startDate?.toIso8601String(),
    'featured': featured,
    'priority': priority,
    'targetAudience': targetAudience,
    if (budgets != null) 'budgets': budgets!.toJson(),
  };

  AdModel copyWith({
    String? title,
    String? businessName,
    String? description,
    String? contact,
    Map<String, String>? socialLinks,
    List<String>? productNames,
    List<String>? photos,
    List<String>? showcasePages,
    String? seeAllImage,
    String? carouselImage,
    MapPin? location,
    List<String>? municipalities,
    String? status,
    AdPayment? payment,
    AdApproval? approval,
    int? duration,
    int? durationDays,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? expiresAt,
    bool? isActive,
    bool? featured,
    int? priority,
    AdAnalytics? analytics,
    Map<String, dynamic>? action,
    String? targetAudience,
    String? kind,
  }) {
    return AdModel(
      id: id,
      title: title ?? this.title,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      socialLinks: socialLinks ?? this.socialLinks,
      productNames: productNames ?? this.productNames,
      photos: photos ?? this.photos,
      showcasePages: showcasePages ?? this.showcasePages,
      seeAllImage: seeAllImage ?? this.seeAllImage,
      carouselImage: carouselImage ?? this.carouselImage,
      location: location ?? this.location,
      // Carried through explicitly: a copyWith that takes no parameter for a
      // field silently resets it to the default — which here would move every
      // service ad back onto the Ads page.
      kind: kind ?? this.kind,
      ownerId: ownerId,
      municipalities: municipalities ?? this.municipalities,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      ownerDisplayName: ownerDisplayName,
      ownerPhotoUrl: ownerPhotoUrl,
      status: status ?? this.status,
      payment: payment ?? this.payment,
      approval: approval ?? this.approval,
      duration: duration ?? this.duration,
      durationDays: durationDays ?? this.durationDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      featured: featured ?? this.featured,
      priority: priority ?? this.priority,
      analytics: analytics ?? this.analytics,
      action: action ?? this.action,
      targetAudience: targetAudience ?? this.targetAudience,
      ownerType: ownerType ?? this.ownerType,
      targetApps: targetApps ?? this.targetApps,
      officialBadgeText: officialBadgeText ?? this.officialBadgeText,
      budgets: budgets ?? this.budgets,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Payment Model
class AdPayment {
  final double feeAmount;
  final bool paid;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentReference;
  final String? transactionId;
  final Map<String, dynamic>?
  refund; // {requested, status, requestedAt, reason, ...}

  AdPayment({
    this.feeAmount = 0,
    this.paid = false,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.transactionId,
    this.refund,
  });

  factory AdPayment.fromJson(Map<String, dynamic> json) => AdPayment(
    feeAmount: (json['feeAmount'] ?? 0).toDouble(),
    paid: json['paid'] ?? false,
    paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
    paymentMethod: json['paymentMethod']?.toString(),
    paymentReference: json['paymentReference']?.toString(),
    transactionId: json['transactionId']?.toString(),
    refund: json['refund'] is Map
        ? Map<String, dynamic>.from(json['refund'])
        : null,
  );
}

// Approval Model
class AdApproval {
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? reviewNotes;

  AdApproval({
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.reviewNotes,
  });

  factory AdApproval.fromJson(Map<String, dynamic> json) => AdApproval(
    submittedAt: json['submittedAt'] != null
        ? DateTime.parse(json['submittedAt'])
        : null,
    approvedBy: json['approvedBy']?.toString(),
    approvedAt: json['approvedAt'] != null
        ? DateTime.parse(json['approvedAt'])
        : null,
    rejectedBy: json['rejectedBy']?.toString(),
    rejectedAt: json['rejectedAt'] != null
        ? DateTime.parse(json['rejectedAt'])
        : null,
    rejectionReason: json['rejectionReason']?.toString(),
    reviewNotes: json['reviewNotes']?.toString(),
  );
}

// Analytics Model
class AdAnalytics {
  final int views;
  final int clicks;
  final int impressions;
  final DateTime? lastViewedAt;

  AdAnalytics({
    this.views = 0,
    this.clicks = 0,
    this.impressions = 0,
    this.lastViewedAt,
  });

  factory AdAnalytics.fromJson(Map<String, dynamic> json) => AdAnalytics(
    views: json['views'] ?? 0,
    clicks: json['clicks'] ?? 0,
    impressions: json['impressions'] ?? 0,
    lastViewedAt: json['lastViewedAt'] != null
        ? DateTime.parse(json['lastViewedAt'])
        : null,
  );
}

// Budget Model
class AdBudget {
  final double? dailyBudget;
  final double? totalBudget;
  final double spentBudget;
  final double dailySpent;
  final DateTime? lastDailyReset;

  AdBudget({
    this.dailyBudget,
    this.totalBudget,
    this.spentBudget = 0,
    this.dailySpent = 0,
    this.lastDailyReset,
  });

  factory AdBudget.fromJson(Map<String, dynamic> json) => AdBudget(
    dailyBudget: json['dailyBudget'] != null ? (json['dailyBudget'] as num).toDouble() : null,
    totalBudget: json['totalBudget'] != null ? (json['totalBudget'] as num).toDouble() : null,
    spentBudget: json['spentBudget'] != null ? (json['spentBudget'] as num).toDouble() : 0,
    dailySpent: json['dailySpent'] != null ? (json['dailySpent'] as num).toDouble() : 0,
    lastDailyReset: json['lastDailyReset'] != null ? DateTime.parse(json['lastDailyReset']) : null,
  );

  Map<String, dynamic> toJson() => {
    if (dailyBudget != null) 'dailyBudget': dailyBudget,
    if (totalBudget != null) 'totalBudget': totalBudget,
    'spentBudget': spentBudget,
    'dailySpent': dailySpent,
    if (lastDailyReset != null) 'lastDailyReset': lastDailyReset?.toIso8601String(),
  };
}

/// A trimmed non-empty string, or null (absent, blank, or not a string).
String? _nonBlankString(Object? raw) {
  if (raw is! String) return null;
  final s = raw.trim();
  return s.isEmpty ? null : s;
}

/// Pages of a LIVE showcase (enabled + non-empty), or an empty list.
/// Tolerant by design: this runs on every ad in every carousel, so a malformed
/// block must degrade to "no showcase" rather than throw.
List<String> _showcasePagesFrom(Object? showcase) {
  if (showcase is! Map) return const [];
  if (showcase['enabled'] != true) return const [];
  final pages = showcase['pages'];
  if (pages is! List) return const [];
  return pages
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
