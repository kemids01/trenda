import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/config.dart';
import '../core/ads/ad_tracking_identity.dart';
import '../models/ad_model.dart';

/// Helper function for MIME type detection
String _getMimeType(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

class AdsRepository {
  final String baseUrl;

  AdsRepository({String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.backendBaseUrl;

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty)
      throw Exception('Failed to get ID token');
    return token;
  }

  Map<String, String> _headers(String token, {bool jsonContent = true}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    if (jsonContent) 'Content-Type': 'application/json',
  };

  // ✅ Validate MongoDB ObjectID format
  void _validateObjectId(String id, String context) {
    // Check for common route names that shouldn't be used as IDs
    const invalidIds = ['create', 'edit', 'new', 'stats', 'settings', 'admin'];
    if (invalidIds.contains(id.toLowerCase())) {
      throw ArgumentError(
        'Invalid ad ID "$id" in $context. '
        'This appears to be a route name, not an ad ID. '
        'Check your navigation/routing logic.',
      );
    }

    // MongoDB ObjectID is 24 hex characters
    final objectIdRegex = RegExp(r'^[0-9a-fA-F]{24}$');
    if (!objectIdRegex.hasMatch(id)) {
      throw ArgumentError(
        'Invalid ad ID format "$id" in $context. '
        'Expected a 24-character hexadecimal string (MongoDB ObjectID). '
        'Received: $id (${id.length} characters)',
      );
    }
  }

  // Fetch public ads (no authentication required) - for guest users
  ///
  /// [kind] narrows to one Shop-tab surface: `'vendor'` for the Ads page,
  /// `'service'` for the Services page. Omitted returns both, which is what
  /// every caller that predates the split sends. The server keeps ads with no
  /// `kind` under 'vendor'.
  Future<Map<String, dynamic>> fetchPublicAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? municipality,
    String? kind,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (municipality != null && municipality.isNotEmpty)
        'municipality': municipality,
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      // Note: Backend getAllAds already filters for active+paid+non-expired
    };

    final uri = Uri.parse(
      '$baseUrl/api/ads',
    ).replace(queryParameters: queryParams);
    // Removed debug log for production

    final headers = {'Accept': 'application/json'};

    final res = await http.get(uri, headers: headers);

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch public ads: ${body['message'] ?? res.body}',
      );
    }

    final ads = (body['data'] ?? []) as List;
    final pagination = body['pagination'] ?? {};

    return {
      'ads': ads.map((e) => AdModel.fromJson(e)).toList(),
      'total': pagination['total'] ?? ads.length,
      'page': pagination['page'] ?? page,
      'totalPages': pagination['pages'] ?? 1,
    };
  }

  // Fetch ads with filters (requires authentication)
  Future<Map<String, dynamic>> fetchAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? ownerId,
    String? status,
    String? municipality, // NEW: Municipality filter
  }) async {
    final token = await _getIdToken();

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (municipality != null && municipality.isNotEmpty)
        'municipality': municipality, // NEW
    };

    final uri = Uri.parse(
      '$baseUrl/api/ads',
    ).replace(queryParameters: queryParams);
    print('🔍 Fetching ads: $uri'); // Debug log

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch ads: ${body['message'] ?? res.body}');
    }

    final ads = (body['data'] ?? []) as List;
    final pagination = body['pagination'] ?? {};

    return {
      'ads': ads.map((e) => AdModel.fromJson(e)).toList(),
      'total': pagination['total'] ?? ads.length,
      'page': pagination['page'] ?? page,
      'totalPages': pagination['pages'] ?? 1,
    };
  }

  // Fetch ads by owner
  Future<List<AdModel>> fetchAdsByOwner(String ownerId) async {
    // If fetching for self, use the dedicated 'my ads' endpoint (returns all statuses)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        (user.uid == ownerId ||
            user.providerData.any((p) => p.uid == ownerId))) {
      return fetchMyAds();
    }

    final result = await fetchAds(limit: 999, ownerId: ownerId);
    return result['ads'] as List<AdModel>;
  }

  // ✅ Fetch MY ads (Authenticated - Returns ALL statuses including draft/expired)
  Future<List<AdModel>> fetchMyAds({int limit = 100, int page = 1}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/my?limit=$limit&page=$page');
    print('🔍 Fetching MY ads: $uri');

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch my ads: ${body['message'] ?? res.body}');
    }

    final ads = (body['data'] ?? []) as List;
    return ads.map((e) => AdModel.fromJson(e)).toList();
  }

  /// Fetch supplier ads visible to vendors (B2B)
  /// Uses dedicated /api/supplier/ads/browse endpoint
  Future<List<AdModel>> fetchSupplierAdsForVendors({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    final token = await _getIdToken();
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (category != null && category.isNotEmpty) 'category': category,
    };

    final uri = Uri.parse(
      '$baseUrl/api/supplier/ads/browse',
    ).replace(queryParameters: queryParams);

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch supplier ads: ${body['message'] ?? res.body}',
      );
    }

    final ads = (body['data'] ?? []) as List;
    return ads.map((e) => AdModel.fromJson(e)).toList();
  }

  // Get ad by ID
  Future<AdModel> getAdById(String id) async {
    print('🔍 getAdById called with: "$id"'); // Debug log

    // ✅ Validate ID before making request
    _validateObjectId(id, 'getAdById');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$id');
    print('🌐 GET: $uri'); // Debug log

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch ad: ${body['message'] ?? res.body}');
    }

    return AdModel.fromJson(body['data']);
  }

  // Create ad
  Future<AdModel> createAd({
    required String title,
    required String businessName,
    String? description,
    String? contact,
    required String ownerId,
    List<File>? photos,
    List<String>? photoUrls,
    int duration = 30,
    int? durationDays,
    String? startDate,
    bool featured = false,
    int priority = 0,
    List<String>? municipalities, // Multi-location targeting
    String?
    targetAudience, // B2B: 'vendor' for supplier ads, 'consumer' for vendor ads
    Map<String, dynamic>? action, // ✅ NEW: Store/Product Link Action
    AdBudget? budgets, // ✅ NEW: Budget Caps
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads');
    print('🌐 POST: $uri'); // Debug log

    if (photos == null || photos.isEmpty) {
      // 🚀 ENTERPRISE PATH: Direct JSON upload using Cloudinary URLs
      final bodyData = {
        'title': title.trim(),
        'businessName': businessName.trim(),
        'owner': ownerId,
        'duration': duration,
        if (durationDays != null) 'durationDays': durationDays,
        if (startDate != null) 'startDate': startDate,
        'featured': featured,
        'priority': priority,
        if (description != null && description.isNotEmpty) 'description': description,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (municipalities != null && municipalities.isNotEmpty) 'municipalities': municipalities,
        if (targetAudience != null && targetAudience.isNotEmpty) 'targetAudience': targetAudience,
        if (action != null) 'action': action,
        if (budgets != null) 'budgets': budgets.toJson(),
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      };

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      final bodyResp = jsonDecode(res.body);
      if (res.statusCode != 201 || bodyResp['success'] != true) {
        throw Exception('Failed to create ad: ${bodyResp['message'] ?? res.body}');
      }

      return AdModel.fromJson(bodyResp['data']);
    }

    // 🐌 LEGACY PATH: Multipart form data for raw files
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $token'});

    request.fields['title'] = title.trim();
    request.fields['businessName'] = businessName.trim();
    request.fields['owner'] = ownerId;
    request.fields['duration'] = duration.toString();
    if (durationDays != null) {
      request.fields['durationDays'] = durationDays.toString();
    }
    if (startDate != null) {
      request.fields['startDate'] = startDate;
    }
    request.fields['featured'] = featured.toString();
    request.fields['priority'] = priority.toString();

    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (contact != null && contact.isNotEmpty) {
      request.fields['contact'] = contact;
    }
    // Multi-location targeting
    if (municipalities != null && municipalities.isNotEmpty) {
      request.fields['municipalities'] = jsonEncode(municipalities);
    }
    // B2B: Target audience for ad visibility
    if (targetAudience != null && targetAudience.isNotEmpty) {
      request.fields['targetAudience'] = targetAudience;
    }
    // Action / Destination
    if (action != null) {
      request.fields['action'] = jsonEncode(action);
    }
    // Budget Caps
    if (budgets != null) {
      request.fields['budgets'] = jsonEncode(budgets.toJson());
    }

    for (final file in photos) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'photos',
          file.path,
          contentType: MediaType.parse(_getMimeType(file.path)),
        ),
      );
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    final body = jsonDecode(res.body);

    if (res.statusCode != 201 || body['success'] != true) {
      throw Exception('Failed to create ad: ${body['message'] ?? res.body}');
    }

    return AdModel.fromJson(body['data']);
  }

  // Mark ad as paid
  Future<void> markAdPaid(
    String id, {
    required String paymentMethod,
    required String paymentReference,
    String? transactionId,
  }) async {
    _validateObjectId(id, 'markAdPaid');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$id/mark-paid');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'transactionId': transactionId,
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to mark ad as paid: ${body['message'] ?? res.body}',
      );
    }
  }

  /// Pay for ad using vendor wallet balance.
  /// Atomically debits wallet, marks ad paid, and submits for approval.
  /// Returns response data with ad and updated wallet balance.
  Future<Map<String, dynamic>> payAdWithWallet(String adId) async {
    _validateObjectId(adId, 'payAdWithWallet');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/pay-with-wallet');

    final res = await http.post(uri, headers: _headers(token));

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to pay with wallet');
    }
    return body['data'] as Map<String, dynamic>;
  }

  // Submit ad for approval
  Future<void> submitForApproval(String id) async {
    _validateObjectId(id, 'submitForApproval');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$id/submit');

    final res = await http.post(uri, headers: _headers(token));
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to submit ad: ${body['message'] ?? res.body}');
    }
  }

  // Update ad
  Future<void> updateAd(
    AdModel ad, {
    List<File>? newPhotos,
    List<String>? photoUrls,
    List<String>? removePhotos,
  }) async {
    _validateObjectId(ad.id, 'updateAd');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/${ad.id}');

    if (newPhotos == null || newPhotos.isEmpty) {
      // 🚀 ENTERPRISE PATH: Direct JSON upload using Cloudinary URLs
      final bodyData = {
        'title': ad.title.trim(),
        'businessName': ad.businessName.trim(),
        'owner': ad.ownerId,
        if (ad.description != null && ad.description!.isNotEmpty) 'description': ad.description!,
        if (ad.contact != null && ad.contact!.isNotEmpty) 'contact': ad.contact!,
        if (removePhotos != null && removePhotos.isNotEmpty) 'removePhotos': removePhotos,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      };

      final res = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      final bodyResp = jsonDecode(res.body);
      if (res.statusCode != 200 || bodyResp['success'] != true) {
        throw Exception('Failed to update ad: ${bodyResp['message'] ?? res.body}');
      }
      return;
    }

    // 🐌 LEGACY PATH: Multipart form data for raw files
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll({'Authorization': 'Bearer $token'});

    request.fields['title'] = ad.title.trim();
    request.fields['businessName'] = ad.businessName.trim();
    request.fields['owner'] = ad.ownerId;

    if (ad.description != null && ad.description!.isNotEmpty) {
      request.fields['description'] = ad.description!;
    }
    if (ad.contact != null && ad.contact!.isNotEmpty) {
      request.fields['contact'] = ad.contact!;
    }
    if (removePhotos != null && removePhotos.isNotEmpty) {
      request.fields['removePhotos'] = jsonEncode(removePhotos);
    }

    if (newPhotos != null && newPhotos.isNotEmpty) {
      for (final file in newPhotos) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photos',
            file.path,
            contentType: MediaType.parse(_getMimeType(file.path)),
          ),
        );
      }
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to update ad: ${body['message'] ?? res.body}');
    }
  }

  // Delete ad
  Future<void> deleteAd(String id) async {
    _validateObjectId(id, 'deleteAd');

    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$id');

    final res = await http.delete(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to delete ad: ${body['message'] ?? res.body}');
    }
  }

  // Get ad stats
  Future<Map<String, dynamic>> getAdStats({String? ownerId}) async {
    final token = await _getIdToken();

    final queryParams = <String, String>{};
    if (ownerId != null) queryParams['ownerId'] = ownerId;

    final uri = Uri.parse(
      '$baseUrl/api/ads/stats/overview',
    ).replace(queryParameters: queryParams);
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch stats: ${body['message'] ?? res.body}');
    }

    return body['data'];
  }

  // Fetch municipalities
  Future<List<dynamic>> fetchMunicipalities({
    bool includeInactive = false,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse(
      '$baseUrl/api/municipalities',
    ).replace(queryParameters: {'includeInactive': includeInactive.toString()});
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch municipalities: ${body['message'] ?? res.body}',
      );
    }

    return body['data'] as List<dynamic>;
  }

  // Fetch ad settings
  Future<Map<String, dynamic>> getAdSettings() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ad-settings');
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch ad settings: ${body['message'] ?? res.body}',
      );
    }

    return body['data'] as Map<String, dynamic>;
  }

  // ✅ NEW: Fetch dynamic fees for municipality
  Future<Map<String, dynamic>> getMunicipalityFees(String municipality) async {
    // This can be public, so token is optional but good to send if available
    Map<String, String> headers = {'Accept': 'application/json'};
    try {
      final token = await _getIdToken();
      headers['Authorization'] = 'Bearer $token';
    } catch (_) {
      // Allow guest access if permitted
    }

    // Prevent double slash issue if municipality is empty
    if (municipality.isEmpty) {
      print(
        'ℹ️ No municipality selected, returning empty fees (using defaults).',
      );
      return {};
    }

    final uri = Uri.parse('$baseUrl/api/municipalities/$municipality/fees');
    print('💰 Fetching fees for $municipality: $uri');

    final res = await http.get(uri, headers: headers);
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      print('⚠️ Failed to fetch fees: ${body['message']}');
      return {}; // Return empty to fallback to defaults
    }

    return body['data'] as Map<String, dynamic>;
  }

  // ============================================================================
  // AD TRACKING - Enterprise Analytics
  // ============================================================================

  /// Track ad view (impression) - fires when ad is displayed
  /// Safe to call without authentication (public route)
  Future<void> trackAdView(String adId) async {
    try {
      _validateObjectId(adId, 'trackAdView');

      final uri = Uri.parse('$baseUrl/api/ads/track/view/$adId');
      // Fire and forget - don't block UI. Identity headers → unique-viewer stats.
      final headers = await AdTrackingIdentity.headers();
      http
          .post(uri, headers: headers)
          .then((res) {
            if (res.statusCode == 200) {
              print('📊 View tracked for ad: $adId');
            }
          })
          .catchError((e) {
            print('⚠️ Failed to track view: $e');
          });
    } catch (e) {
      print('⚠️ Track view error: $e');
    }
  }

  /// Track ad click - fires when user interacts with the ad
  /// Safe to call without authentication (public route)
  Future<void> trackAdClick(String adId) async {
    try {
      _validateObjectId(adId, 'trackAdClick');

      final uri = Uri.parse('$baseUrl/api/ads/track/click/$adId');
      // Fire and forget - don't block UI. Identity headers → unique-tapper stats.
      final headers = await AdTrackingIdentity.headers();
      http
          .post(uri, headers: headers)
          .then((res) {
            if (res.statusCode == 200) {
              print('🖱️ Click tracked for ad: $adId');
            }
          })
          .catchError((e) {
            print('⚠️ Failed to track click: $e');
          });
    } catch (e) {
      print('⚠️ Track click error: $e');
    }
  }

  /// Track multiple ad views (batch impressions)
  /// Useful for carousel/list views where multiple ads are shown at once
  void trackAdViews(List<String> adIds) {
    for (final adId in adIds) {
      trackAdView(adId);
    }
  }

  /// Report/flag an inappropriate ad (consumer action)
  /// reason: inappropriate_content, misleading, spam, offensive, fraud, other
  Future<void> reportAd(String adId, {required String reason, String? description}) async {
    _validateObjectId(adId, 'reportAd');

    final uri = Uri.parse('$baseUrl/api/ads/report/$adId');
    final res = await http.post(
      uri,
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'reason': reason,
        if (description != null && description.isNotEmpty) 'description': description,
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to report ad');
    }
  }

  // ============================================================================
  // AD REFUND - Vendor refund requests
  // ============================================================================

  /// Check if an ad is eligible for refund
  Future<Map<String, dynamic>> checkRefundEligibility(String adId) async {
    _validateObjectId(adId, 'checkRefundEligibility');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/refund-eligibility');

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to check refund eligibility: ${body['message'] ?? res.body}',
      );
    }

    return body;
  }

  /// Request a refund for an ad
  Future<void> requestAdRefund(String adId, {required String reason}) async {
    _validateObjectId(adId, 'requestAdRefund');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/request-refund');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'reason': reason}),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to request refund: ${body['message'] ?? res.body}',
      );
    }
  }

  // ============================================================================
  // VENDOR ANALYTICS - Dashboard, Performance, Spending
  // ============================================================================

  /// Get vendor's ad dashboard stats (total ads, views, clicks, spending, etc.)
  Future<Map<String, dynamic>> getVendorDashboard({int period = 30}) async {
    final token = await _getIdToken();
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/analytics/dashboard',
    ).replace(queryParameters: {'period': period.toString()});

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch vendor dashboard: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Export vendor's ad analytics as CSV string
  Future<String> exportAdAnalyticsCsv({int period = 30}) async {
    final token = await _getIdToken();
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/analytics/export',
    ).replace(queryParameters: {'period': period.toString()});

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to export analytics: ${res.body}');
    }
    return res.body;
  }

  /// Get detailed performance analytics for vendor's ads
  Future<Map<String, dynamic>> getVendorPerformanceAnalytics({
    int period = 30,
    String? adId,
  }) async {
    final token = await _getIdToken();
    final queryParams = <String, String>{
      'period': period.toString(),
      if (adId != null) 'adId': adId,
    };
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/analytics/performance',
    ).replace(queryParameters: queryParams);

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch performance analytics: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Get vendor's spending and ROI analytics
  Future<Map<String, dynamic>> getVendorSpendingAnalytics({
    int period = 30,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/analytics/spending',
    ).replace(queryParameters: {'period': period.toString()});

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch spending analytics: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Get detailed analytics for a single ad
  Future<Map<String, dynamic>> getSingleAdAnalytics(String adId) async {
    _validateObjectId(adId, 'getSingleAdAnalytics');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/analytics/$adId');

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch ad analytics: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Compare analytics for multiple ads (2-5 ad IDs)
  Future<Map<String, dynamic>> compareAds(List<String> adIds) async {
    if (adIds.length < 2 || adIds.length > 5) {
      throw ArgumentError('Must provide 2-5 ad IDs for comparison');
    }
    for (final id in adIds) {
      _validateObjectId(id, 'compareAds');
    }
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/analytics/compare');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'adIds': adIds}),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to compare ads: ${body['message'] ?? res.body}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  // ============================================================================
  // AD ROI ANALYTICS - Per-ad ROI detail
  // ============================================================================

  /// Get detailed ROI for a specific ad
  Future<Map<String, dynamic>> getAdRoiDetails(String adId) async {
    _validateObjectId(adId, 'getAdRoiDetails');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/roi/$adId');

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch ad ROI details: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Get vendor's ads ROI analytics summary
  Future<Map<String, dynamic>> getVendorAdsRoi() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/my/roi');

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch ROI data: ${body['message'] ?? res.body}',
      );
    }

    return body['data'] as Map<String, dynamic>;
  }

  // ============================================================================
  // REFUND HISTORY
  // ============================================================================

  /// Get vendor's refund request history
  Future<Map<String, dynamic>> getMyRefunds({
    int page = 1,
    int limit = 20,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/my/refunds').replace(
      queryParameters: {'page': page.toString(), 'limit': limit.toString()},
    );

    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch refund history: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  // ============================================================================
  // WAITLIST - Cancel waitlist slot
  // ============================================================================

  /// Cancel a waitlist slot for an ad
  Future<void> cancelWaitlistSlot(String adId) async {
    _validateObjectId(adId, 'cancelWaitlistSlot');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/cancel-waitlist');

    final res = await http.post(uri, headers: _headers(token));
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to cancel waitlist: ${body['message'] ?? res.body}',
      );
    }
  }

  /// Cancel a pending ad and get wallet refund if applicable
  Future<Map<String, dynamic>> cancelPendingAd(String adId) async {
    _validateObjectId(adId, 'cancelPendingAd');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/cancel');

    final res = await http.post(uri, headers: _headers(token));
    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        body['message'] ?? 'Failed to cancel ad',
      );
    }
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  // ===========================================================================
  // BILLING DISPUTES
  // ===========================================================================

  Future<Map<String, dynamic>> getMyDisputes({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final token = await _getIdToken();
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (status != null) 'status': status,
    };
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/disputes',
    ).replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch disputes: ${body['message'] ?? res.body}',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> createBillingDispute({
    required String adId,
    required String reason,
    required double disputedAmount,
    String? description,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/disputes');
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'adId': adId,
        'reason': reason,
        'disputedAmount': disputedAmount,
        if (description != null) 'description': description,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 201 && res.statusCode != 200 ||
        body['success'] != true) {
      throw Exception(
        'Failed to create dispute: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> getDisputeDetails(String disputeId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/disputes/$disputeId');
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch dispute: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] ?? {};
  }

  Future<void> addDisputeEvidence({
    required String disputeId,
    required String evidenceType,
    required String content,
    String? description,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse(
      '$baseUrl/api/vendor/ads/disputes/$disputeId/evidence',
    );
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'evidenceType': evidenceType,
        'content': content,
        if (description != null) 'description': description,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to add evidence: ${body['message'] ?? res.body}');
    }
  }

  // ============================================================================
  // AD INVENTORY
  // ============================================================================

  /// Get monthly slot inventory for a municipality
  Future<Map<String, dynamic>> getMonthlyInventory({
    required String municipalityId,
    required int year,
    required int month,
  }) async {
    final token = await _getIdToken();
    final params = <String, String>{
      'municipalityId': municipalityId,
      'year': '$year',
      'month': '$month',
    };
    final uri = Uri.parse(
      '$baseUrl/api/inventory/calendar',
    ).replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: _headers(token, jsonContent: false),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch inventory: ${body['message'] ?? res.body}',
      );
    }
    return body['data'] ?? body;
  }

  /// Reserve ad slots
  Future<Map<String, dynamic>> reserveSlots({
    required String municipalityId,
    required String startDate,
    required int duration,
    bool featured = false,
    int priority = 0,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/inventory/reserve');
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'municipalityId': municipalityId,
        'startDate': startDate,
        'duration': duration,
        'featured': featured,
        'priority': priority,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201 ||
        body['success'] != true) {
      throw Exception('Failed to reserve: ${body['message'] ?? res.body}');
    }
    return body['data'] ?? {};
  }

  /// Get invoice/receipt for vendor's own ad
  Future<Map<String, dynamic>> getAdInvoice(String adId) async {
    _validateObjectId(adId, 'getAdInvoice');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/invoice');
    final res = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to get invoice');
    }
    return body['data'] ?? {};
  }

  /// ✅ NEW: Fetch Cloudinary secure upload parameters
  Future<Map<String, dynamic>?> getAdUploadParams() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/upload-params');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        return body['data'];
      }
    }
    return null;
  }

  /// Renew an expired/rejected ad (clone into new draft)
  Future<Map<String, dynamic>> renewAd(String adId) async {
    _validateObjectId(adId, 'renewAd');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/renew');
    final res = await http.post(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201 ||
        body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to renew ad');
    }
    return body['data'] ?? {};
  }

  /// Pause an active ad (preserves remaining days)
  Future<Map<String, dynamic>> pauseAd(String adId, {String? reason}) async {
    _validateObjectId(adId, 'pauseAd');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/pause');
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'reason': reason ?? ''}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to pause ad');
    }
    return body['data'] ?? {};
  }

  /// Resume a paused ad (extends endDate by paused duration)
  Future<Map<String, dynamic>> resumeAd(String adId) async {
    _validateObjectId(adId, 'resumeAd');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/resume');
    final res = await http.post(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to resume ad');
    }
    return body['data'] ?? {};
  }

  /// Extend an active ad by additional days (paid via wallet)
  Future<Map<String, dynamic>> extendAd(
    String adId, {
    required int days,
  }) async {
    _validateObjectId(adId, 'extendAd');
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/ads/$adId/extend');
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'days': days}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to extend ad');
    }
    return body['data'] ?? {};
  }

  /// Get vendor's ad payment history (all ad payments)
  Future<Map<String, dynamic>> getMyAdPaymentHistory({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final token = await _getIdToken();
    final params = {'page': '$page', 'limit': '$limit'};
    if (status != null) params['status'] = status;
    final uri = Uri.parse(
      '$baseUrl/api/ads/my-payments',
    ).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to get payment history');
    }
    return body['data'] ?? {};
  }

  // ============================================================================
  // AD TEMPLATES — Save/Load reusable ad content templates
  // ============================================================================

  /// List vendor's ad templates
  Future<List<Map<String, dynamic>>> getMyAdTemplates() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/templates');
    final res = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to fetch templates');
    }
    return List<Map<String, dynamic>>.from(body['data'] ?? []);
  }

  /// Get a single template by ID
  Future<Map<String, dynamic>> getAdTemplate(String id) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/templates/$id');
    final res = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Template not found');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Create a new ad template from current ad form data
  Future<Map<String, dynamic>> createAdTemplate(
    Map<String, dynamic> data,
  ) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/templates');
    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 201 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create template');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Delete a template
  Future<void> deleteAdTemplate(String id) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/vendor/ads/templates/$id');
    final res = await http.delete(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete template');
    }
  }

  // ============================================================================
  // OFFICIAL TRENDA ADS (Admin-only)
  // ============================================================================

  /// Create an official Trenda platform ad (auto-approved, multi-app targeting)
  Future<Map<String, dynamic>> createOfficialAd({
    required String title,
    required List<String> targetApps,
    List<String> slots = const [],
    String? imageUrl,
    Map<String, String>? slotImages,
    bool tappable = false,
    Map<String, dynamic>? landing,
    String? businessName,
    String? description,
    String? contact,
    List<String>? municipalities,
    int durationDays = 30,
    bool featured = true,
    int priority = 10,
    int abWeight = 1,
    Map<String, dynamic>? daypart,
    String? badgeText,
    double? paymentAmount,
    String? paymentMethod,
    String? paymentReference,
    String? paidBy,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/create-official-ad');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'targetApps': targetApps,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'placement': {
          'slots': slots,
          // A LIST, not a map: slot ids contain dots and the server's request sanitizer
          // deletes every dotted key, so a map keyed by slot id never arrived.
          if (slotImages != null && slotImages.isNotEmpty)
            'slotImages': [for (final e in slotImages.entries) {'slot': e.key, 'image': e.value}],
          'tappable': tappable,
          'landing': landing ?? {'enabled': false, 'cta': {'type': 'none'}},
        },
        if (businessName != null) 'businessName': businessName,
        if (description != null) 'description': description,
        if (contact != null) 'contact': contact,
        if (municipalities != null) 'municipalities': municipalities,
        'durationDays': durationDays,
        'featured': featured,
        'priority': priority,
        'abWeight': abWeight,
        if (daypart != null) 'daypart': daypart,
        if (badgeText != null) 'badgeText': badgeText,
        if (paymentAmount != null) 'paymentAmount': paymentAmount,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (paymentReference != null) 'paymentReference': paymentReference,
        if (paidBy != null) 'paidBy': paidBy,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 201 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to create official ad');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Edit an official ad (partial — send only the fields to change).
  Future<void> updateOfficialAd(String id, Map<String, dynamic> body) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/official-ads/$id');
    final res = await http.put(uri, headers: _headers(token), body: jsonEncode(body));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['message'] ?? 'Failed to update official ad');
    }
  }

  Future<void> _officialAdAction(String id, String action) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/official-ads/$id/$action');
    final res = await http.post(uri, headers: _headers(token));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['message'] ?? 'Failed to $action official ad');
    }
  }

  Future<void> pauseOfficialAd(String id) => _officialAdAction(id, 'pause');
  Future<void> resumeOfficialAd(String id) => _officialAdAction(id, 'resume');

  Future<void> deleteOfficialAd(String id) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/official-ads/$id');
    final res = await http.delete(uri, headers: _headers(token));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['message'] ?? 'Failed to delete official ad');
    }
  }

  Future<List<Map<String, dynamic>>> fetchOfficialAdLogs(String id) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/$id/logs');
    final res = await http.get(uri, headers: _headers(token));
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(res.body)['data'] ?? []);
  }

  Future<Map<String, dynamic>> getOfficialAdUploadParams() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/admin/ads/enhanced/upload-params');
    final res = await http.get(uri, headers: _headers(token));
    if (res.statusCode != 200) {
      throw Exception('Failed to get upload params');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body)['data'] ?? {});
  }

  /// List all official Trenda ads
  Future<Map<String, dynamic>> fetchOfficialAds({
    String? status,
    String? targetApp,
    int page = 1,
    int limit = 20,
  }) async {
    final token = await _getIdToken();
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (status != null) 'status': status,
      if (targetApp != null) 'targetApp': targetApp,
    };
    final uri = Uri.parse(
      '$baseUrl/api/admin/ads/enhanced/official-ads',
    ).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to fetch official ads');
    }
    return body;
  }
}
