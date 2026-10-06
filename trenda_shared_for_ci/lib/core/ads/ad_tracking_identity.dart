// trenda_shared/lib/core/ads/ad_tracking_identity.dart
// Who is looking at an ad — sent with every ad view/tap ping so the backend can count UNIQUE
// viewers and tappers (trenda_backend utils/adAudience.js), not just raw totals.
//
//   • x-trenda-device — an anonymous install id: random, created once, kept on the device. It is
//     how a logged-out shopper is counted once. Not personal data.
//   • x-trenda-app    — which app sent the ping. Each app sets [AdTrackingIdentity.app] once in
//     main(); left unset the ping still counts, filed under "unknown".
//   • Authorization   — the signed-in user's Firebase token, when there is one, so a user is
//     counted by their account across devices.
// Every step is best-effort: tracking must never delay or break the screen showing the ad.
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdTrackingIdentity {
  AdTrackingIdentity._();

  /// 'frontend' | 'vendor' | 'supplier' | 'rider' — set once in each app's main().
  static String? app;

  static const _prefsKey = 'trenda_ad_install_id';
  static String? _installId;

  /// This install's anonymous id (created on first use, then reused forever).
  static Future<String?> installId() async {
    if (_installId != null) return _installId;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_prefsKey);
      if (id == null || !isValidInstallId(id)) {
        id = generateInstallId();
        await prefs.setString(_prefsKey, id);
      }
      return _installId = id;
    } catch (_) {
      return null; // storage unavailable → counted as unidentified (totals only)
    }
  }

  /// Headers for an ad tracking request. Never throws.
  static Future<Map<String, String>> headers() async {
    String? token;
    try {
      token = await FirebaseAuth.instance.currentUser
          ?.getIdToken()
          .timeout(const Duration(seconds: 3));
    } catch (_) {/* not signed in / Firebase not ready → anonymous */}
    return buildAdTrackingHeaders(installId: await installId(), app: app, token: token);
  }
}

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

/// A 22-char random id (~132 bits) from a URL-safe alphabet the backend accepts.
String generateInstallId([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(22, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

/// Mirrors the backend's accepted shape (`^[A-Za-z0-9_-]{8,64}$`).
bool isValidInstallId(String id) => RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id);

/// Pure header builder — only includes what is known.
Map<String, String> buildAdTrackingHeaders({String? installId, String? app, String? token}) => {
      'Accept': 'application/json',
      if (installId != null && installId.isNotEmpty) 'x-trenda-device': installId,
      if (app != null && app.isNotEmpty) 'x-trenda-app': app,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
