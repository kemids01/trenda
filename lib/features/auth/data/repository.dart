// lib/features/auth/data/repository.dart
// ------------------------------------------------------------
// Firebase Auth + Google Sign-In (v7.2.0) + MongoDB Backend Sync
// Uses GoogleSignIn.instance + initialize() + authenticate()
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:developer';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';

/// AuthRepository: wraps Google sign-in (v7.2.0), Email/Password, Phone OTP,
/// linking, sign-out and auto-sync to your Express + MongoDB backend.
class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Backend API base URL (uses centralized config)
  String get _apiBaseUrl => '${AppConfig.backendBaseUrl}/api';

  AuthRepository(this._auth, this._googleSignIn);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ============================================================
  // GOOGLE SIGN-IN (v7.2.0)
  // - Use GoogleSignIn.instance
  // - Call initialize() optionally with serverClientId (if provided)
  // - Use authenticate() to do interactive sign-in
  // API reference: google_sign_in 7.2.0 docs (initialize, authenticate, instance).
  // See: https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn-class.html
  // ============================================================

  Future<User?> signInWithGoogle() async {
    try {
      final credential = await _getGoogleCredential();
      if (credential == null) return null;

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      // Sync to backend (create or update)
      if (user != null) await _syncUserWithBackend(user);

      return user;
    } catch (e, st) {
      log('Google sign-in error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Link Google account to existing Firebase user.
  Future<void> linkWithGoogle(User user) async {
    try {
      final credential = await _getGoogleCredential();
      if (credential == null) return;

      await user.linkWithCredential(credential);

      // Sync updated profile
      await _syncUserWithBackend(user);
    } catch (e, st) {
      log('linkWithGoogle failed: $e', stackTrace: st);
      rethrow;
    }
  }

  // ============================================================
  // FACEBOOK SIGN-IN
  // ============================================================

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final credential =
            FacebookAuthProvider.credential(accessToken.tokenString);

        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;

        if (user != null) await _syncUserWithBackend(user);
        return user;
      } else if (result.status == LoginStatus.cancelled) {
        log('Facebook login cancelled by user');
        return null;
      } else {
        log('Facebook login failed: ${result.message}');
        throw Exception(result.message ?? 'Facebook sign-in failed.');
      }
    } catch (e, st) {
      log('Facebook sign-in error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Link Facebook account to existing Firebase user.
  Future<void> linkWithFacebook(User user) async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final credential =
            FacebookAuthProvider.credential(accessToken.tokenString);

        await user.linkWithCredential(credential);
        await _syncUserWithBackend(user);
      } else if (result.status != LoginStatus.cancelled) {
        throw Exception(result.message ?? 'Facebook link failed.');
      }
    } catch (e, st) {
      log('linkWithFacebook failed: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Private helper: obtains Firebase AuthCredential from Google tokens.
  /// Uses initialize() then authenticate() (v7.2.0 API).
  Future<AuthCredential?> _getGoogleCredential() async {
    try {
      // Allow setting server client id for production via --dart-define:
      // flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID="....apps.googleusercontent.com"
      final serverClientId = const String.fromEnvironment(
          'GOOGLE_SERVER_CLIENT_ID',
          defaultValue: '');

      log('📱 Google Sign-In: Starting initialization...');

      // initialize() configures the underlying sign-in implementation.
      if (serverClientId.isNotEmpty) {
        await _googleSignIn.initialize(serverClientId: serverClientId);
      } else {
        await _googleSignIn.initialize();
      }

      log('📱 Google Sign-In: Initialized, checking authenticate support...');

      // If the platform supports authenticate(), use it for an interactive flow.
      GoogleSignInAccount account;
      if (_googleSignIn.supportsAuthenticate()) {
        log('📱 Google Sign-In: Using authenticate() flow');
        // interactive sign-in (shows account selection UI)
        account = await _googleSignIn
            .authenticate(scopeHint: ['openid', 'email', 'profile']);
      } else {
        log('📱 Google Sign-In: Using lightweight authentication');
        // fallback: attempt lightweight auth (may return null)
        final maybeAccount =
            await _googleSignIn.attemptLightweightAuthentication();
        if (maybeAccount == null) {
          log('⚠️ Google Sign-In: Lightweight auth returned null');
          return null;
        }
        account = maybeAccount;
      }

      log('📱 Google Sign-In: Got account: ${account.email}');

      // Retrieve tokens and convert to Firebase credential
      final googleAuth = account.authentication;

      log('📱 Google Sign-In: idToken exists: ${googleAuth.idToken != null}');

      // ✅ Firebase credential from Google idToken
      return GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
    } catch (e, st) {
      log('❌ _getGoogleCredential error: $e', stackTrace: st);
      rethrow;
    }
  }

  // ============================================================
  // Backend auto-sync: creates or updates profile at POST /api/users
  // Requires Firebase ID token in Authorization header (Bearer <token>)
  // ============================================================

  Future<void> _syncUserWithBackend(User user) async {
    try {
      final token = await user.getIdToken();
      // Use /users/sync endpoint (not /users which is admin-only)
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/users/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'displayName': user.displayName ?? '',
          'photoURL':
              user.photoURL ?? 'https://i.pravatar.cc/150?u=${user.uid}',
          'email': user.email,
          'phone': user.phoneNumber,
        }),
      );

      if (response.statusCode >= 400) {
        log('Backend sync failed: ${response.statusCode} ${response.body}');
      } else {
        log('User synced with backend successfully');
      }
    } catch (e, st) {
      log('Backend sync error: $e', stackTrace: st);
    }
  }

  // ---------------------------
  // Phone / Email flows (unchanged)
  // ---------------------------

  Future<void> changePhoneNumber({
    required String newPhoneNumber,
    required void Function(ConfirmationResult) onCodeSent,
    required void Function(User user) onVerified,
    required void Function(Object error) onError,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      onError("No logged-in user ❌");
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: newPhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final res = await currentUser.linkWithCredential(credential);
            if (res.user != null) {
              await _syncUserWithBackend(res.user!);
              onVerified(res.user!);
            }
          } catch (e) {
            log('Auto verification during phone change failed: $e');
            onError(e);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          log('Phone verification failed: ${e.message}');
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(ConfirmationResult(
              verificationId: verificationId, resendToken: resendToken));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          log('Code auto-retrieval timeout: $verificationId');
        },
      );
    } catch (e) {
      log('changePhoneNumber error: $e');
      onError(e);
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = result.user;
      if (user != null) await _syncUserWithBackend(user);
      return user;
    } catch (e, st) {
      log('Email sign-in error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, st) {
      log('Password reset error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> sendOtp(
    String phoneNumber, {
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(User user) onAutoVerified,
    required void Function(Object error) onError,
    bool linkMode = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Backend successfully "sent" OTP.
        // We reuse the 'phoneNumber' as the verificationId for simplicity in this flow,
        // or we could ask the backend to return a session ID.
        // For now, pass phoneNumber as verificationId.
        onCodeSent(phoneNumber, null);

        if (data['devNote'] != null) {
          log('DEV MODE OTP: ${data['devNote']}');
        }
      } else {
        onError(data['message'] ?? 'Failed to send OTP');
      }
    } catch (e, st) {
      log('sendOtp error: $e', stackTrace: st);
      onError(e);
    }
  }

  Future<void> resendOtp(
    String phoneNumber, {
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(User user) onAutoVerified,
    required void Function(Object error) onError,
    bool linkMode = false,
  }) async {
    // Backend doesn't distinguish resend yet, just call send again
    await sendOtp(
      phoneNumber,
      onCodeSent: onCodeSent,
      onAutoVerified: onAutoVerified,
      onError: onError,
      linkMode: linkMode,
    );
  }

  Future<User?> verifyOtp({
    required String verificationId,
    required String smsCode,
    required bool linkMode,
  }) async {
    try {
      // verificationId is actually phoneNumber in our new flow
      final phoneNumber = verificationId;

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otp': smsCode,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final customToken = data['token'];
        log('✅ Phone Verified. Signing in with Custom Token...');

        UserCredential res;
        if (linkMode && _auth.currentUser != null) {
          // Linking is trickier with custom tokens directly if the provider isn't same
          // Usually you'd link a credential. Custom Token is a full sign-in mechanism.
          // For now, let's treat it as a sign-in. If linking is strict req,
          // we might need to exchange custom token for a credential or handle merging backend-side.
          // Given constraints, we'll Sign In.
          res = await _auth.signInWithCustomToken(customToken);
        } else {
          res = await _auth.signInWithCustomToken(customToken);
        }

        if (res.user != null) {
          await _syncUserWithBackend(res.user!);
          return res.user;
        }
      } else {
        throw Exception(data['message'] ?? 'Verification failed');
      }
      return null;
    } catch (e, st) {
      log('verifyOtp error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Signs out of Firebase AND Google. Without the Google half, the next sign-in
  /// silently reused the same Google account — there was no way to switch.
  /// (`disconnect()` is deliberately NOT called: it revokes the app's grant, so
  /// every later sign-in would ask for consent again.)
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      // Firebase is already signed out, which is what gates the app.
      log('Google sign-out error: $e', stackTrace: st);
    }
    try {
      await FacebookAuth.instance.logOut();
    } catch (e, st) {
      log('Facebook sign-out error: $e', stackTrace: st);
    }
    log('User signed out');
  }
}

/// Helper class to simulate ConfirmationResult for phone flows.
class ConfirmationResult {
  final String verificationId;
  final int? resendToken;
  ConfirmationResult({required this.verificationId, this.resendToken});
}
