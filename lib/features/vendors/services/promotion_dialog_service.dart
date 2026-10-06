// lib/features/vendors/services/promotion_dialog_service.dart
// Service for fetching and tracking promotion dialog data
// ============================================================================

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/config.dart';
import '../../../widgets/promotion_dialog_popup.dart';

class PromotionDialogService {
  final Dio _dio;

  /// In-memory session tracking: vendors whose dialog has been shown this session
  static final Set<String> _shownThisSession = {};

  PromotionDialogService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  /// Reset session tracking (call on app restart or logout)
  static void resetSession() => _shownThisSession.clear();

  /// Mark a vendor's dialog as shown in this session
  static void markAsShown(String vendorId) => _shownThisSession.add(vendorId);

  /// Check if the dialog should be shown based on session + settings
  static bool shouldShowDialog(String vendorId, PromotionDialogData data) {
    // Always show if showOnEveryVisit is true
    if (data.showOnEveryVisit) return true;
    // Otherwise, only show if not yet shown this session
    return !_shownThisSession.contains(vendorId);
  }

  Future<Map<String, String>?> _getAuthHeaders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      return {'Authorization': 'Bearer $token'};
    } catch (e) {
      return null;
    }
  }

  /// Fetch promotion dialog for a vendor
  Future<PromotionDialogData?> getVendorDialog(String vendorId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '/api/promotion-dialog/$vendorId',
        options: headers != null ? Options(headers: headers) : null,
      );

      final responseBody = response.data as Map<String, dynamic>;
      // Unwrap ApiResponse wrapper: { success, data: { dialog, hasDialog } }
      final data =
          responseBody['data'] as Map<String, dynamic>? ?? responseBody;
      if (data['dialog'] != null &&
          ((data['dialog']['slides'] as List?)?.isNotEmpty ?? false)) {
        return PromotionDialogData.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Track impression for a slide
  Future<void> trackImpression(String vendorId, String slideId) async {
    try {
      final headers = await _getAuthHeaders();
      await _dio.post(
        '/api/promotion-dialog/$vendorId/impression',
        data: {'slideId': slideId},
        options: headers != null ? Options(headers: headers) : null,
      );
    } catch (e) {
      // Silent failure
    }
  }

  /// Track product click for a slide
  Future<void> trackProductClick(String vendorId, String slideId) async {
    try {
      final headers = await _getAuthHeaders();
      await _dio.post(
        '/api/promotion-dialog/$vendorId/product-click',
        data: {'slideId': slideId},
        options: headers != null ? Options(headers: headers) : null,
      );
    } catch (e) {
      // Silent failure
    }
  }
}
