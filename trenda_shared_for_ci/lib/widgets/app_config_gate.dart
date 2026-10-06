// AppConfigGate — wraps an app's root and enforces the admin app-remote-config:
//   • maintenance mode  → full-screen maintenance notice (with retry)
//   • force update      → full-screen update-required notice (when currentVersion
//                          is below minAppVersion[appKey]); skipped when null
//   • emergency broadcast → dismissible banner above the app
// Degrades gracefully: while loading or on any fetch error it shows the child, so
// a config outage never blocks the app. Self-contained (no Riverpod dependency).
import 'package:flutter/material.dart';
import '../data/app_config_repository.dart';
import '../models/app_runtime_config.dart';
import '../core/timezone.dart';

/// App-wide current version (e.g. `PackageInfo.version`), set once in `main()`
/// before `runApp`. `AppConfigGate` uses it for the force-update check when no
/// explicit `currentVersion` is passed. Null → force-update check is skipped.
String? currentAppVersion;

/// The last app-remote-config fetched by `AppConfigGate`, exposed so any screen
/// can read admin-configured platform values (name, currency) without refetching.
AppRuntimeConfig? currentAppConfig;

/// Admin-configured platform name (Settings → platform.name); falls back to 'Trenda'.
String get platformName {
  final n = currentAppConfig?.platform['name'];
  return (n != null && n.isNotEmpty) ? n : 'Trenda';
}

/// Admin-configured currency symbol (Settings → platform.currency); falls back to ₱.
String get platformCurrencySymbol {
  final c = currentAppConfig?.platform['currency'];
  return (c != null && c.isNotEmpty) ? c : '₱';
}

/// Formats an amount with the platform currency symbol, e.g. `₱1,234.50`.
String formatMoney(num amount, {int decimals = 2}) {
  final s = amount.toStringAsFixed(decimals);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  return '$platformCurrencySymbol$intPart$dec';
}

class AppConfigGate extends StatefulWidget {
  final Widget child;
  final String appKey; // 'consumer' | 'vendor' | 'delivery'
  final String? currentVersion;
  const AppConfigGate({
    super.key,
    required this.child,
    required this.appKey,
    this.currentVersion,
  });

  @override
  State<AppConfigGate> createState() => _AppConfigGateState();
}

class _AppConfigGateState extends State<AppConfigGate> {
  AppRuntimeConfig? _cfg;
  bool _loaded = false;
  bool _broadcastDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await AppConfigRepository.fetch();
    if (c != null) currentAppConfig = c; // expose to the whole app
    if (!mounted) return;
    setState(() {
      _cfg = c;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _cfg;
    // Loading or unreachable → never block the app.
    if (!_loaded || c == null) return widget.child;

    if (c.maintenance.enabled) {
      return _MaintenanceScreen(maintenance: c.maintenance, onRetry: _load);
    }

    final min = c.minAppVersion[widget.appKey] ?? '1.0.0';
    final version = widget.currentVersion ?? currentAppVersion;
    if (version != null && isVersionBelow(version, min)) {
      return _ForceUpdateScreen(minVersion: min);
    }

    if (c.broadcast.active && !_broadcastDismissed) {
      return Column(
        children: [
          _BroadcastBanner(
            broadcast: c.broadcast,
            onDismiss: () => setState(() => _broadcastDismissed = true),
          ),
          Expanded(child: widget.child),
        ],
      );
    }
    return widget.child;
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final AppMaintenance maintenance;
  final VoidCallback onRetry;
  const _MaintenanceScreen({required this.maintenance, required this.onRetry});

  String? _endTimeLabel(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    final l = dt.toManilaTime;
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined,
                    size: 72, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  'Under Maintenance',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  maintenance.message.isNotEmpty
                      ? maintenance.message
                      : 'We’re making things better. Please check back shortly.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                if (_endTimeLabel(maintenance.estimatedEndTime) != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Expected back: ${_endTimeLabel(maintenance.estimatedEndTime)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final String minVersion;
  const _ForceUpdateScreen({required this.minVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 72, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Update Required',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'A newer version (v$minVersion or later) is required to continue. '
                  'Please update the app from your app store.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  final AppEmergencyBroadcast broadcast;
  final VoidCallback onDismiss;
  const _BroadcastBanner({required this.broadcast, required this.onDismiss});

  Color get _color {
    switch (broadcast.type) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _color.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.campaign, color: _color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (broadcast.title.isNotEmpty)
                      Text(broadcast.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _color)),
                    if (broadcast.message.isNotEmpty)
                      Text(broadcast.message,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
