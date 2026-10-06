// trenda_shared/lib/core/remote_config.dart
// Shared remote config provider for vendor/delivery/consumer apps
// Fetches maintenance mode, feature flags, and version info from backend
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'config.dart';

/// Remote config data from admin backend
class RemoteConfig {
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final Map<String, bool> featureFlags;
  final String minAppVersion;
  final bool emergencyBroadcastActive;
  final String emergencyTitle;
  final String emergencyMessage;
  final String emergencyType;

  RemoteConfig({
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.featureFlags = const {},
    this.minAppVersion = '1.0.0',
    this.emergencyBroadcastActive = false,
    this.emergencyTitle = '',
    this.emergencyMessage = '',
    this.emergencyType = 'info',
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final maintenance = json['maintenanceMode'] as Map<String, dynamic>? ?? {};
    final flags = json['featureFlags'] as Map<String, dynamic>? ?? {};
    final versions = json['minAppVersion'] as Map<String, dynamic>? ?? {};
    final broadcast = json['emergencyBroadcast'] as Map<String, dynamic>? ?? {};

    return RemoteConfig(
      maintenanceEnabled: maintenance['enabled'] == true,
      maintenanceMessage:
          maintenance['message']?.toString() ?? 'System is under maintenance',
      featureFlags: flags.map((k, v) => MapEntry(k, v == true)),
      minAppVersion: versions['consumer']?.toString() ?? '1.0.0',
      emergencyBroadcastActive: broadcast['active'] == true,
      emergencyTitle: broadcast['title']?.toString() ?? '',
      emergencyMessage: broadcast['message']?.toString() ?? '',
      emergencyType: broadcast['type']?.toString() ?? 'info',
    );
  }

  /// Check if a feature is enabled
  bool isFeatureEnabled(String feature) => featureFlags[feature] ?? true;

  /// Check if COD is enabled
  bool get cashOnDeliveryEnabled => isFeatureEnabled('cashOnDelivery');

  /// Check if online payment is enabled
  bool get onlinePaymentEnabled => isFeatureEnabled('onlinePayment');

  /// Check if flash sales are enabled
  bool get flashSalesEnabled => isFeatureEnabled('flashSales');

  /// Check if gift cards are enabled
  bool get giftCardsEnabled => isFeatureEnabled('giftCards');

  /// Check if vendor registration is enabled
  bool get vendorRegistrationEnabled => isFeatureEnabled('vendorRegistration');

  /// Check if rider registration is enabled
  bool get riderRegistrationEnabled => isFeatureEnabled('riderRegistration');
}

/// Remote config provider - fetches config from backend
/// Use with: ref.watch(remoteConfigProvider)
final remoteConfigProvider = FutureProvider<RemoteConfig>((ref) async {
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.backendBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Public endpoint - no auth required
    final response = await dio.get('/api/admin/enhanced/app-config');

    if (response.data['success'] == true && response.data['data'] != null) {
      return RemoteConfig.fromJson(response.data['data']);
    }
    return RemoteConfig();
  } catch (e) {
    print('⚠️ RemoteConfig: Failed to fetch - using defaults. Error: $e');
    return RemoteConfig();
  }
});

/// Auto-refresh provider that polls every 5 minutes
final remoteConfigAutoRefreshProvider = StreamProvider<RemoteConfig>((
  ref,
) async* {
  while (true) {
    final config = await ref.read(remoteConfigProvider.future);
    yield config;
    await Future.delayed(const Duration(minutes: 5));
    ref.invalidate(remoteConfigProvider);
  }
});
