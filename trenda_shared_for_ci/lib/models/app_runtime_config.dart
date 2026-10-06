// Public app-remote-config consumed by the customer/vendor/delivery apps.
// Mirrors GET /api/config/app. Feature flags default to ENABLED so a missing
// value never accidentally hides a feature.

class AppMaintenance {
  final bool enabled;
  final String message;
  final String? estimatedEndTime;
  const AppMaintenance({
    required this.enabled,
    required this.message,
    this.estimatedEndTime,
  });

  factory AppMaintenance.fromJson(Map<String, dynamic> j) => AppMaintenance(
        enabled: j['enabled'] == true,
        message: (j['message'] ?? '').toString(),
        estimatedEndTime: j['estimatedEndTime']?.toString(),
      );
}

class AppEmergencyBroadcast {
  final bool active;
  final String title;
  final String message;
  final String type; // info | warning | error
  const AppEmergencyBroadcast({
    required this.active,
    required this.title,
    required this.message,
    required this.type,
  });

  factory AppEmergencyBroadcast.fromJson(Map<String, dynamic> j) =>
      AppEmergencyBroadcast(
        active: j['active'] == true,
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        type: (j['type'] ?? 'info').toString(),
      );
}

class AppRuntimeConfig {
  final AppMaintenance maintenance;
  final Map<String, bool> featureFlags;
  final Map<String, String> minAppVersion;
  final AppEmergencyBroadcast broadcast;
  final Map<String, String> platform;

  const AppRuntimeConfig({
    required this.maintenance,
    required this.featureFlags,
    required this.minAppVersion,
    required this.broadcast,
    required this.platform,
  });

  /// A feature flag; defaults to true (enabled) when absent.
  bool flag(String key) => featureFlags[key] ?? true;

  factory AppRuntimeConfig.fromJson(Map<String, dynamic> j) {
    final ff = <String, bool>{};
    final rawFlags = j['featureFlags'];
    if (rawFlags is Map) {
      rawFlags.forEach((k, v) => ff['$k'] = v != false);
    }
    final mv = <String, String>{};
    final rawVer = j['minAppVersion'];
    if (rawVer is Map) {
      rawVer.forEach((k, v) => mv['$k'] = (v ?? '1.0.0').toString());
    }
    final plat = <String, String>{};
    final rawPlat = j['platform'];
    if (rawPlat is Map) {
      rawPlat.forEach((k, v) => plat['$k'] = (v ?? '').toString());
    }
    return AppRuntimeConfig(
      maintenance: AppMaintenance.fromJson(
          (j['maintenanceMode'] as Map?)?.cast<String, dynamic>() ?? const {}),
      featureFlags: ff,
      minAppVersion: mv,
      broadcast: AppEmergencyBroadcast.fromJson(
          (j['emergencyBroadcast'] as Map?)?.cast<String, dynamic>() ??
              const {}),
      platform: plat,
    );
  }
}

/// Pure: is [current] semver strictly below [min]? Unparseable input → false
/// (never force an update we can't reason about).
bool isVersionBelow(String current, String min) {
  List<int>? parse(String v) {
    final parts = v.trim().split('.');
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n == null) return null;
      out.add(n);
    }
    return out.isEmpty ? null : out;
  }

  final a = parse(current);
  final b = parse(min);
  if (a == null || b == null) return false;
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x < y) return true;
    if (x > y) return false;
  }
  return false;
}
