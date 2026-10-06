// lib/features/checkout/utils/location_capture.dart
//
// One hardened path for capturing the device's current GPS position at checkout.
// Both the GPS-only address body and the "detect my location" map flow use this so
// the service-enabled check, permission handling, timeout, and friendly error
// messages stay consistent (they had drifted apart before).
import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Result of a GPS capture attempt: either a [position] or a user-facing [error].
class GpsCaptureResult {
  final Position? position;
  final String? error;

  const GpsCaptureResult.success(Position this.position) : error = null;
  const GpsCaptureResult.failure(String this.error) : position = null;

  bool get ok => position != null;
}

/// Maps a geolocation exception to a clear, user-facing message.
/// Pure — unit tested; keep in sync with the failure branches in
/// [captureCurrentPosition].
String gpsFailureMessage(Object error) {
  if (error is LocationServiceDisabledException) {
    return 'Location services are off. Turn on GPS/Location in your device '
        'settings, then tap Refresh.';
  }
  if (error is TimeoutException) {
    return 'Getting your location took too long. Move to an open area and try again.';
  }
  if (error is PermissionDeniedException) {
    return 'Location permission denied. Allow location access to use GPS, or use '
        'a saved address.';
  }
  final s = error.toString().toLowerCase();
  if (s.contains('permission')) {
    return 'Location permission denied. Allow location access to use GPS, or use '
        'a saved address.';
  }
  if (s.contains('service') || s.contains('disabled')) {
    return 'Location services are off. Turn on GPS/Location in your device '
        'settings, then tap Refresh.';
  }
  return 'Could not get your location. Please try again or use a saved address.';
}

/// Captures the current position with a device-services check, permission
/// handling, and a hard [timeout] so it can never hang. Never throws — returns a
/// [GpsCaptureResult] carrying either the position or a friendly message.
Future<GpsCaptureResult> captureCurrentPosition({
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return GpsCaptureResult.failure(
        gpsFailureMessage(const LocationServiceDisabledException()),
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const GpsCaptureResult.failure(
        'Location permission denied. Allow location access to use GPS, or use a '
        'saved address.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const GpsCaptureResult.failure(
        'Location permission is permanently denied. Enable it in your device '
        'settings to use GPS.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
    return GpsCaptureResult.success(position);
  } catch (e) {
    return GpsCaptureResult.failure(gpsFailureMessage(e));
  }
}
