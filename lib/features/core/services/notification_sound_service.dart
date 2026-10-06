// lib/features/core/services/notification_sound_service.dart
// ============================================================================
// NOTIFICATION SOUND SERVICE - Customer App Version
// ============================================================================
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for notification sound service
final notificationSoundProvider = Provider<NotificationSoundService>((ref) {
  return NotificationSoundService();
});

/// Service for playing notification sounds using system feedback
class NotificationSoundService {
  bool _isSoundEnabled = true;

  NotificationSoundService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
  }

  /// Play new product notification from followed vendor
  Future<void> playNewProductSound() async {
    if (!_isSoundEnabled) return;

    // Medium haptic for new product
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  /// Play order update sound
  Future<void> playOrderUpdateSound() async {
    if (!_isSoundEnabled) return;

    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// Play message received sound
  Future<void> playMessageSound() async {
    if (!_isSoundEnabled) return;

    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// Play promotion/deal alert
  Future<void> playPromoSound() async {
    if (!_isSoundEnabled) return;

    // Double haptic for attention
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  /// Play order confirmed sound (celebration)
  Future<void> playOrderConfirmedSound() async {
    if (!_isSoundEnabled) return;

    // Triple haptic celebration
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Play delivery arrived sound
  Future<void> playDeliverySound() async {
    if (!_isSoundEnabled) return;

    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  /// Toggle sound on/off
  Future<void> toggleSound(bool enabled) async {
    _isSoundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_sound_enabled', enabled);
  }

  bool get isSoundEnabled => _isSoundEnabled;
}
