// lib/features/core/providers/connectivity_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ✅ StreamProvider that emits `true` if there's REAL Internet access.
/// Includes debounce + stable transitions for smoother banner animation.
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final controller = StreamController<bool>();
  final connectivity = Connectivity();

  bool lastOnline = true;
  Timer? debounceTimer;

  Future<void> emitState(bool online) async {
    // Prevent rapid-fire toggles causing jittery banners
    if (online == lastOnline) return;

    lastOnline = online;
    controller.add(online);
  }

  // ✅ Initial check
  final initial = await connectivity.checkConnectivity();
  final initialOnline = await _verifyConnection(initial);
  emitState(initialOnline);

  // ✅ Listen to connectivity changes
  await for (final result in connectivity.onConnectivityChanged) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final verified = await _verifyConnection(result);
      emitState(verified);
    });
  }

  ref.onDispose(() {
    debounceTimer?.cancel();
    controller.close();
  });

  yield* controller.stream.distinct();
});

/// ✅ Handles both single and list connectivity results
Future<bool> _verifyConnection(dynamic result) async {
  try {
    final List<ConnectivityResult> results =
        result is List<ConnectivityResult> ? result : [result];

    // No network interfaces
    if (results.contains(ConnectivityResult.none)) return false;

    // Check actual internet access
    final lookup = await InternetAddress.lookup('example.com')
        .timeout(const Duration(seconds: 3));
    return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
