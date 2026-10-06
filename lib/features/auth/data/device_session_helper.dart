//lib/features/auth/data/device_session_helper.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class DeviceSessionHelper {
  static final _firestore = FirebaseFirestore.instance;

  /// Generate a unique device ID for Android, iOS, or fallback
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        // Use 'id' if available, fallback to generated UUID
        return info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? const Uuid().v4();
      } else {
        // Fallback for other platforms
        return const Uuid().v4();
      }
    } catch (_) {
      // Fallback if device info fails
      return const Uuid().v4();
    }
  }

  /// Check if this device can login (handle stale sessions)
  static Future<bool> canLogin(String uid, String deviceId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .get();

    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      if (doc.id != deviceId) {
        // Check if session is older than 7 days (stale session)
        final lastActiveData = doc.data()['lastActive'];
        if (lastActiveData != null) {
          final lastActive = (lastActiveData as Timestamp).toDate();
          final daysSinceActive = now.difference(lastActive).inDays;

          if (daysSinceActive >= 7) {
            // Delete stale session and continue checking
            await doc.reference.delete();
            continue;
          }

          // Valid active session on another device - block login
          return false;
        } else {
          // No lastActive timestamp - delete this invalid session
          await doc.reference.delete();
        }
      }
    }
    return true;
  }

  /// Register current device session
  static Future<void> createSession(String uid, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(deviceId)
        .set({
      'lastActive': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    });
  }

  /// Remove session on logout
  static Future<void> deleteSession(String uid, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(deviceId)
        .delete();
  }
}
