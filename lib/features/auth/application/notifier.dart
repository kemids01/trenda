// lib/features/auth/application/notifier.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io'; // For InternetAddress (network check)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trenda_frontend/features/auth/data/resend_timer_provider.dart';
import 'package:trenda_frontend/features/home/application/profile_action_notifier.dart';
import 'package:trenda_frontend/features/home/application/user_profile_notifier.dart';
import 'state.dart';
import 'auth_error_messages.dart';
import '../data/repository.dart' hide ConfirmationResult;
import '../../core/providers/tab_provider.dart';

/// ------------------- Auth Notifier -------------------
/// Manages all authentication logic, user state, OTP, linking, and profile updates
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository; // Repository for API & Firebase calls
  final Ref ref; // Riverpod reference for reading other providers

  // Track auth state to prevent spam
  bool _hasProcessedInitialState = false;
  String? _currentUserUid;

  /// Constructor initializes state and listens to Firebase auth state changes
  AuthNotifier(this._repository, this.ref) : super(AuthState.initial()) {
    _repository.authStateChanges.listen((user) async {
      if (!mounted) return;

      // Handle signed-in user
      if (user != null) {
        // Skip if same user - prevent spam
        if (_currentUserUid == user.uid &&
            state.status == AuthStatus.authenticated) {
          return;
        }

        // Update user UID tracker
        _currentUserUid = user.uid;

        // Update state with authenticated user
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        // Skip if already unauthenticated and we've processed at least once
        if (_hasProcessedInitialState &&
            _currentUserUid == null &&
            state.status == AuthStatus.unauthenticated) {
          return;
        }

        _hasProcessedInitialState = true;
        _currentUserUid = null;

        // No user is signed in
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
        );
      }
    });
  }

  /// ------------------- Utilities -------------------
  /// Maps Firebase error codes to user-friendly messages
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'credential-already-in-use':
        return "That account is already used on another profile. You may want to merge accounts.";
      case 'provider-already-linked':
        return "This provider is already linked to this account.";
      case 'email-already-in-use':
        return "Email already linked to another account.";
      case 'account-exists-with-different-credential':
        return "This email is linked with a different sign-in method.";
      case 'wrong-password':
        return "Invalid password. Please try again.";
      case 'network-request-failed':
        return "Network error, please check your connection 🌐";
      case 'invalid-credential':
        return "Invalid or expired credential. Please try again.";
      case 'user-disabled':
        return "Account disabled. Contact support.";
      default:
        return e.message ?? "Authentication failed.";
    }
  }

  /// ------------------- ID Token Helper -------------------
  /// Returns Firebase ID token for the current logged-in user
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = state.user;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (e, st) {
      log("getIdToken failed: $e", stackTrace: st);
      state = state.copyWith(
          status: AuthStatus.error, errorMsg: "Failed to get ID token");
      return null;
    }
  }

  /// ------------------- Authenticated Request Helper -------------------
  /// Wraps API requests and automatically adds Firebase ID token
  /// Wraps API requests and automatically adds a valid Firebase ID token
  Future<T?> authRequest<T>(
      Future<T> Function(String idToken) requestFunc) async {
    final user = state.user;
    if (user == null) {
      state = state.copyWith(errorMsg: "User not authenticated ❌");
      return null;
    }

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        debugPrint("⚠️ Firebase returned empty token");
        state = state.copyWith(errorMsg: "Failed to retrieve ID token ❌");
        return null;
      }

      debugPrint("✅ Got token prefix: ${token.substring(0, 15)}...");
      return await _retryOnNetwork(() => requestFunc(token));
    } catch (e, st) {
      log("authRequest failed: $e", stackTrace: st);
      state = state.copyWith(errorMsg: "Authentication error ❌");
      return null;
    }
  }

  // /// ------------------- Example: Add Address -------------------
  // /// Adds a user address and updates the profile state
  // Future<void> addAddress(UserAddress address) async {
  //   await authRequest((idToken) async {
  //     final response = await http.post(
  //       Uri.parse('https://your-backend.com/user/${state.user!.uid}/address'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $idToken',
  //       },
  //       body: json.encode(address.toJson()),
  //     );

  //     final profileNotifier = ref.read(userProfileProvider.notifier);

  //     if (response.statusCode == 201) {
  //       try {
  //         final addedAddress =
  //             UserAddress.fromJson(json.decode(response.body)['data']);
  //         profileNotifier.addAddress(addedAddress); // Safely update profile
  //       } catch (e, st) {
  //         log('Failed to parse added address: $e', stackTrace: st);
  //         profileNotifier.setError("Failed to parse added address");
  //       }
  //     } else {
  //       profileNotifier.setError("Failed to add address: ${response.body}");
  //     }
  //   });
  // }

  /// ------------------- Linking Helpers -------------------
  /// Links a new credential (Google, Email, etc.) to the current user
  Future<void> linkCredential(AuthCredential credential) async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "No logged-in user to link ❌",
      );
      return;
    }

    // Check if provider is already linked
    final providerId = credential.providerId;
    final alreadyLinked =
        currentUser.providerData.any((p) => p.providerId == providerId);

    if (alreadyLinked) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "$providerId already linked to this account.",
      );
      return;
    }

    try {
      await currentUser.linkWithCredential(credential);
      await currentUser.reload();
      final refreshedUser = _repository.currentUser;

      // ✅ Sync with backend so MongoDB knows about the new provider
      if (refreshedUser != null) {
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(refreshedUser);
      }

      state = state.copyWith(
        user: refreshedUser,
        successMsg: "$providerId linked successfully 🎉",
      );
      ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
    } on FirebaseAuthException catch (e, st) {
      log("linkCredential failed: $e", stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: _mapFirebaseError(e),
      );
    } catch (e, st) {
      log("linkCredential failed (non-Firebase): $e", stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "Unexpected error: $e",
      );
    }
  }

  /// ------------------- Network Utilities -------------------
  /// Checks if network is available by pinging Firebase
  Future<bool> _checkNetwork() async {
    try {
      final result =
          await InternetAddress.lookup('firebase.google.com').timeout(
        const Duration(seconds: 3),
      );
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Retry action automatically when network is available
  Future<T?> _retryOnNetwork<T>(
    Future<T> Function() action, {
    int retries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < retries; i++) {
      if (await _checkNetwork()) {
        try {
          return await action();
        } catch (_) {
          await Future.delayed(delay);
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMsg: "No Internet connection. Please check your network 🌐",
        );
        return null;
      }
    }
    state = state.copyWith(
      status: AuthStatus.error,
      errorMsg: "Network error. Please try again later.",
    );
    return null;
  }

  /// ------------------- Getters -------------------
  bool get hasPasswordProvider =>
      state.user?.providerData.any((p) => p.providerId == "password") ?? false;

  bool get canShowPassword => hasPasswordProvider;

  /// ------------------- Linking Methods -------------------
  Future<void> linkWithPassword(String email, String password) async {
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await linkCredential(credential);
  }

  Future<void> linkWithGoogle() async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "No logged-in user to link ❌",
      );
      return;
    }

    state = state.copyWith(
      loadingGoogle: true,
      errorMsg: null,
      successMsg: null,
    );

    try {
      await _repository
          .linkWithGoogle(currentUser); // your existing repo method
      await currentUser.reload();
      final refreshedUser = _repository.currentUser;

      state = state.copyWith(
        user: refreshedUser,
        loadingGoogle: false,
        successMsg: "Google account linked successfully 🎉",
      );
      ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
    } catch (e, st) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: e.toString(),
        loadingGoogle: false,
      );
      log("linkWithGoogle failed: $e", stackTrace: st);
    }
  }

  /// ------------------- Account Management -------------------
  Future<void> changePhoneNumber({
    required String newPhoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(User) onVerified,
    required void Function(Object error) onError,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
          status: AuthStatus.error, errorMsg: "No user logged in ❌");
      return;
    }

    try {
      await _repository.changePhoneNumber(
        newPhoneNumber: newPhoneNumber,
        onCodeSent: (confirmation) {
          onCodeSent(confirmation.verificationId, confirmation.resendToken);
        },
        onVerified: (user) async {
          await currentUser.reload();
          final refreshedUser = _repository.currentUser;
          state = state.copyWith(
              user: refreshedUser, successMsg: "Phone number updated 🎉");
          onVerified(user);
        },
        onError: onError,
      );
    } catch (e, st) {
      log("changePhoneNumber failed: $e", stackTrace: st);
      state = state.copyWith(status: AuthStatus.error, errorMsg: e.toString());
    }
  }

  Future<bool> reauthenticateUser(
      {required String email, required String password}) async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
          status: AuthStatus.error, errorMsg: "No logged-in user ❌");
      return false;
    }

    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.reload();
      state = state.copyWith(
          user: _repository.currentUser,
          successMsg: "Reauthentication successful ✅");
      return true;
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = "Incorrect password";
          break;
        case 'user-mismatch':
          msg = "Credential does not match current user";
          break;
        case 'user-not-found':
          msg = "User not found";
          break;
        default:
          msg = e.message ?? "Reauthentication failed";
      }
      state = state.copyWith(status: AuthStatus.error, errorMsg: msg);
      return false;
    } catch (e) {
      state = state.copyWith(
          status: AuthStatus.error, errorMsg: "Reauthentication error: $e");
      return false;
    }
  }

  Future<void> linkGoogleIfPhone() async {
    final currentUser = state.user;
    if (currentUser == null) return;

    final providers =
        currentUser.providerData.map((p) => p.providerId).toList();
    if (providers.contains("phone") && !providers.contains("google.com")) {
      await linkWithGoogle();
    } else {
      state = state.copyWith(successMsg: "Google already linked ✅");
    }
  }

  /// Unlink Google provider
  /// ------------------- Unlink Google -------------------
  Future<void> unlinkGoogle() async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "No logged-in user to unlink ❌",
      );
      return;
    }

    // Check if Google is linked
    final isLinked =
        currentUser.providerData.any((p) => p.providerId == 'google.com');
    if (!isLinked) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "Google is not linked to this account ❌",
      );
      return;
    }

    try {
      await currentUser.unlink('google.com');
      await currentUser.reload();
      final refreshedUser = _repository.currentUser;

      // ✅ Sync with backend so MongoDB knows provider was removed
      if (refreshedUser != null) {
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(refreshedUser);
      }

      state = state.copyWith(
        user: refreshedUser,
        successMsg: "Google account unlinked successfully ✅",
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: e.message ?? "Failed to unlink Google",
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "Unexpected error: $e",
      );
    }
  }

  /// ------------------- New Wrappers -------------------
  /// Links a phone number to the current user (like "linkWithPhone")
  Future<void> linkWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(User) onVerified,
    required void Function(Object error) onError,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "No logged-in user ❌",
      );
      return;
    }

    try {
      await _repository.changePhoneNumber(
        newPhoneNumber: phoneNumber,
        onCodeSent: (confirmation) {
          onCodeSent(confirmation.verificationId, confirmation.resendToken);
        },
        onVerified: (user) async {
          await currentUser.reload();
          final refreshedUser = _repository.currentUser;
          state = state.copyWith(
              user: refreshedUser, successMsg: "Phone linked successfully 🎉");
          onVerified(user);
        },
        onError: onError,
      );
    } catch (e, st) {
      log("linkWithPhone failed: $e", stackTrace: st);
      state = state.copyWith(status: AuthStatus.error, errorMsg: e.toString());
    }
  }

  /// Updates phone number directly (like "updatePhoneNumber")
  Future<void> updatePhoneNumber({
    required String newPhoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(User) onVerified,
    required void Function(Object error) onError,
  }) async {
    await changePhoneNumber(
      newPhoneNumber: newPhoneNumber,
      onCodeSent: onCodeSent,
      onVerified: onVerified,
      onError: onError,
    );
  }

  /// ------------------- Sign-In with Google -------------------
  Future<void> signInWithGoogle() async {
    state =
        state.copyWith(loadingGoogle: true, errorMsg: null, successMsg: null);
    try {
      final user = await _retryOnNetwork(() => _repository.signInWithGoogle());
      if (!mounted) return;

      if (user != null) {
        // ✅ Sync user to MongoDB automatically
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          successMsg: "Welcome, ${user.displayName ?? 'User'}! 🎉",
          loadingGoogle: false,
        );
        ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMsg: "Google sign-in failed ❌",
          loadingGoogle: false,
        );
      }
    } on PlatformException catch (e, st) {
      if (!mounted) return;
      log('Google Sign-In PlatformException: $e', stackTrace: st);

      String errorMsg = "Google Sign-In failed ❌";
      // Detect Common SHA-1 mismatch error (ApiException: 10)
      if (e.toString().contains('ApiException: 10') ||
          e.code == 'sign_in_failed') {
        errorMsg =
            "SETUP ERROR: SHA-1 key mismatch. \nAdd your debug keystore SHA-1 to Firebase Console.";
      } else if (e.code == 'network_error') {
        errorMsg = "Network error. Please check your connection.";
      } else {
        errorMsg = "Sign-In Error: ${e.message ?? e.code}";
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: errorMsg,
        loadingGoogle: false,
      );
    } catch (e, st) {
      if (!mounted) return;
      log('signInWithGoogle failed: $e', stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: friendlyAuthError(e),
        loadingGoogle: false,
      );
    }
  }

  /// ------------------- Sign-In with Facebook -------------------
  Future<void> signInWithFacebook() async {
    state =
        state.copyWith(loadingFacebook: true, errorMsg: null, successMsg: null);
    try {
      final user =
          await _retryOnNetwork(() => _repository.signInWithFacebook());
      if (!mounted) return;

      if (user != null) {
        // ✅ Sync user to MongoDB automatically
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          successMsg: "Welcome, ${user.displayName ?? 'User'}! 🎉",
          loadingFacebook: false,
        );
        ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          loadingFacebook: false,
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      log('signInWithFacebook failed: $e', stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: friendlyAuthError(e),
        loadingFacebook: false,
      );
    }
  }

  Future<void> linkWithFacebook() async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: "No logged-in user to link ❌",
      );
      return;
    }

    state = state.copyWith(
      loadingFacebook: true,
      errorMsg: null,
      successMsg: null,
    );

    try {
      await _repository.linkWithFacebook(currentUser);
      await currentUser.reload();
      final refreshedUser = _repository.currentUser;

      state = state.copyWith(
        user: refreshedUser,
        loadingFacebook: false,
        successMsg: "Facebook account linked successfully 🎉",
      );
      ref.read(profileOpenRequestProvider.notifier).state++;
    } catch (e, st) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: friendlyAuthError(e),
        loadingFacebook: false,
      );
      log("linkWithFacebook failed: $e", stackTrace: st);
    }
  }

  /// ------------------- Sign-In with Email -------------------
  Future<void> signInWithEmail(String email, String password) async {
    state =
        state.copyWith(loadingEmail: true, errorMsg: null, successMsg: null);
    try {
      final user = await _repository.signInWithEmail(email, password);
      if (!mounted) return;

      if (user != null) {
        // ✅ Sync user to MongoDB automatically
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(user); // call public sync method

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          successMsg: "Welcome, ${user.displayName ?? email}! 🎉",
          loadingEmail: false,
        );
        ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMsg: "Email sign-in failed ❌",
          loadingEmail: false,
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      log('signInWithEmail failed: $e', stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: friendlyAuthError(e),
        loadingEmail: false,
      );
    }
  }

  /// ------------------- Password Reset -------------------
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(
        status: AuthStatus.loading, errorMsg: null, successMsg: null);
    try {
      await _repository.sendPasswordReset(email);
      if (!mounted) return;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        successMsg: "Password reset email sent ✅",
      );
    } catch (e, st) {
      if (!mounted) return;
      log('sendPasswordReset failed: $e', stackTrace: st);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: friendlyAuthError(e),
      );
    }
  }

  /// ------------------- OTP Send -------------------
  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(
        sendingOtp: true, otpStatus: OtpStatus.idle, errorMsg: null);

    try {
      await _repository.sendOtp(
        phoneNumber,
        onCodeSent: (verificationId, _) {
          if (!mounted) return;
          state = state.copyWith(
            otpStatus: OtpStatus.codeSent,
            verificationId: verificationId,
            sendingOtp: false,
          );
          ref.read(otpResendTimerProvider.notifier).startCountdown();
        },
        onAutoVerified: (user) {
          if (!mounted) return;
          ref.read(otpResendTimerProvider.notifier).reset();
          state = state.copyWith(
            otpStatus: OtpStatus.verified,
            status: AuthStatus.authenticated,
            user: user,
            successMsg: "Phone verified ✅",
          );
        },
        onError: (error) {
          if (!mounted) return;
          state = state.copyWith(
            otpStatus: OtpStatus.failed,
            errorMsg: friendlyAuthError(error),
            sendingOtp: false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        otpStatus: OtpStatus.failed,
        errorMsg: friendlyAuthError(e),
        sendingOtp: false,
      );
    }
  }

  void setOtpFailed(String errorMsg) {
    if (!mounted) return;
    state = state.copyWith(
        otpStatus: OtpStatus.failed,
        verifyingOtp: false,
        sendingOtp: false,
        errorMsg: errorMsg);
  }

  void resetOtp() {
    if (!mounted) return;
    ref.read(otpResendTimerProvider.notifier).reset();
    state = state.copyWith(
        otpStatus: OtpStatus.idle, verificationId: null, errorMsg: null);
  }

  void setEmailError(String? message) {
    if (!mounted) return;
    state = state.copyWith(emailError: message);
  }

  Future<void> resendOtp(String phoneNumber) async {
    if (ref.read(otpResendTimerProvider) > 0) return;

    state = state.copyWith(otpStatus: OtpStatus.resending, errorMsg: null);

    try {
      await _repository.sendOtp(
        phoneNumber,
        onCodeSent: (verificationId, _) {
          if (!mounted) return;
          state = state.copyWith(
              otpStatus: OtpStatus.codeSent, verificationId: verificationId);
          ref.read(otpResendTimerProvider.notifier).startCountdown();
        },
        onAutoVerified: (user) {
          if (!mounted) return;
          ref.read(otpResendTimerProvider.notifier).reset();
          state = state.copyWith(
              status: AuthStatus.authenticated,
              otpStatus: OtpStatus.verified,
              user: user);
          ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
        },
        onError: (error) {
          if (!mounted) return;
          state = state.copyWith(
              otpStatus: OtpStatus.failed, errorMsg: friendlyAuthError(error));
        },
      );
    } catch (e) {
      if (!mounted) return;
      state =
          state.copyWith(otpStatus: OtpStatus.failed, errorMsg: friendlyAuthError(e));
    }
  }

  /// ------------------- Verify OTP -------------------
  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
    bool linkMode = false,
  }) async {
    state = state.copyWith(
        verifyingOtp: true,
        otpStatus: OtpStatus.verifying,
        errorMsg: null,
        successMsg: null);

    try {
      final user = await _repository.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
        linkMode: linkMode,
      );
      if (!mounted) return;

      if (user != null) {
        // ✅ Sync user to MongoDB automatically
        final profileNotifier = ref.read(userProfileProvider.notifier);
        await profileNotifier.syncUser(user); // call public sync method

        state = state.copyWith(
          status: AuthStatus.authenticated,
          verifyingOtp: false,
          otpStatus: OtpStatus.verified,
          user: user,
          successMsg: "Phone verified ✅",
        );
        ref.read(profileOpenRequestProvider.notifier).state++; // open the Profile page
      } else {
        state = state.copyWith(
          verifyingOtp: false,
          otpStatus: OtpStatus.failed,
          errorMsg: "OTP verification failed ❌",
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      log('verifyOtp failed: $e', stackTrace: st);
      state = state.copyWith(
        verifyingOtp: false,
        otpStatus: OtpStatus.failed,
        errorMsg: friendlyAuthError(e),
      );
    }
  }

  /// ------------------- Sign Out -------------------
  Future<void> signOut() async {
    try {
      // Reset profile & action states first
      ref.read(userProfileProvider.notifier).reset();
      ref.read(profileActionProvider.notifier).reset();

      // Firebase + Google. The account-scoped providers (cart, orders, …) reset
      // themselves off currentUidProvider when the user becomes null.
      await _repository.signOut();

      // Immediately update AuthNotifier state
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );

      // Optionally, clear transient messages
      clearTransientMessages();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: e.toString(),
      );
    }
  }

  /// Clear transient messages
  void clearTransientMessages() {
    if (!mounted) return;
    state = state.copyWith(errorMsg: null, successMsg: null);
  }
}
