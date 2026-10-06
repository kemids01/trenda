// lib/features/vendors/services/vendor_follow_service.dart
// ============================================================================
// VENDOR FOLLOW SERVICE - Subscribe to Vendor Updates
// ============================================================================
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/vendor_follow_provider.dart';

/// Provider for vendor follow service
final vendorFollowServiceProvider = Provider<VendorFollowService>((ref) {
  return VendorFollowService(ref);
});

/// Service for following vendors and receiving notifications
class VendorFollowService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const _followedVendorsKey = 'followed_vendors';

  VendorFollowService(this._ref);

  /// Follow a vendor and subscribe to their notifications
  Future<bool> followVendor(String vendorId, {String? vendorName}) async {
    try {
      // Subscribe to FCM topic for this vendor
      await _messaging.subscribeToTopic('vendor_$vendorId');

      // Save locally
      await _saveFollowedVendor(vendorId, vendorName);

      // Notify backend
      await _notifyBackendFollow(vendorId, true);

      if (kDebugMode) {
        print('✅ Followed vendor: $vendorId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to follow vendor: $e');
      }
      return false;
    }
  }

  /// Unfollow a vendor
  Future<bool> unfollowVendor(String vendorId) async {
    try {
      // Unsubscribe from FCM topic
      await _messaging.unsubscribeFromTopic('vendor_$vendorId');

      // Remove from local storage
      await _removeFollowedVendor(vendorId);

      // Notify backend
      await _notifyBackendFollow(vendorId, false);

      if (kDebugMode) {
        print('✅ Unfollowed vendor: $vendorId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to unfollow vendor: $e');
      }
      return false;
    }
  }

  /// Check if following a vendor
  Future<bool> isFollowing(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = prefs.getStringList(_followedVendorsKey) ?? [];
    return followed.contains(vendorId);
  }

  /// Get list of followed vendor IDs
  Future<List<String>> getFollowedVendorIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_followedVendorsKey) ?? [];
  }

  /// Toggle follow status
  Future<bool> toggleFollow(String vendorId, {String? vendorName}) async {
    final isCurrentlyFollowing = await isFollowing(vendorId);
    if (isCurrentlyFollowing) {
      return await unfollowVendor(vendorId);
    } else {
      return await followVendor(vendorId, vendorName: vendorName);
    }
  }

  Future<void> _saveFollowedVendor(String vendorId, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = prefs.getStringList(_followedVendorsKey) ?? [];
    if (!followed.contains(vendorId)) {
      followed.add(vendorId);
      await prefs.setStringList(_followedVendorsKey, followed);
    }
  }

  Future<void> _removeFollowedVendor(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = prefs.getStringList(_followedVendorsKey) ?? [];
    followed.remove(vendorId);
    await prefs.setStringList(_followedVendorsKey, followed);
  }

  Future<void> _notifyBackendFollow(String vendorId, bool isFollowing) async {
    try {
      // Call API to update follow status on backend
      final repo = _ref.read(vendorRepositoryProvider);
      await repo.updateFollowStatus(vendorId, isFollowing);
    } catch (e) {
      // Log but don't fail - local follow is already saved
      if (kDebugMode) {
        print('⚠️ Failed to notify backend of follow: $e');
      }
    }
  }

  /// Re-subscribe to all followed vendors (call on app start)
  Future<void> resubscribeToFollowedVendors() async {
    final vendorIds = await getFollowedVendorIds();
    for (final vendorId in vendorIds) {
      try {
        await _messaging.subscribeToTopic('vendor_$vendorId');
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to resubscribe to vendor_$vendorId: $e');
        }
      }
    }
    if (kDebugMode) {
      print('📱 Resubscribed to ${vendorIds.length} vendor topics');
    }
  }
}
