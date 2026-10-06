// lib/features/auth/application/state.dart
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

enum OtpStatus { idle, codeSent, verifying, verified, failed, resending }

class AuthState {
  final AuthStatus status;
  final OtpStatus otpStatus;
  final User? user; // ✅ Correctly typed
  final bool loadingEmail;
  final bool loadingGoogle;
  final bool loadingFacebook;
  final bool sendingOtp;
  final bool verifyingOtp;
  final String? errorMsg;
  final String? successMsg;
  final String? emailError;
  final String? verificationId;
  final int resendCountdown;
  static const _noUser = Object();

  const AuthState({
    required this.status,
    required this.otpStatus,
    this.user,
    this.loadingEmail = false,
    this.loadingGoogle = false,
    this.loadingFacebook = false,
    this.sendingOtp = false,
    this.verifyingOtp = false,
    this.errorMsg,
    this.successMsg,
    this.emailError,
    this.verificationId,
    this.resendCountdown = 0,
  });

  factory AuthState.initial() => const AuthState(
        status: AuthStatus.initial,
        otpStatus: OtpStatus.idle,
      );

  AuthState copyWith({
    AuthStatus? status,
    OtpStatus? otpStatus,
    Object? user = _noUser, // sentinel
    bool? loadingEmail,
    bool? loadingGoogle,
    bool? loadingFacebook,
    bool? sendingOtp,
    bool? verifyingOtp,
    String? errorMsg,
    String? successMsg,
    String? emailError,
    String? verificationId,
    int? resendCountdown,
  }) {
    return AuthState(
      status: status ?? this.status,
      otpStatus: otpStatus ?? this.otpStatus,
      user: user == _noUser ? this.user : user as User?,
      loadingEmail: loadingEmail ?? this.loadingEmail,
      loadingGoogle: loadingGoogle ?? this.loadingGoogle,
      loadingFacebook: loadingFacebook ?? this.loadingFacebook,
      sendingOtp: sendingOtp ?? this.sendingOtp,
      verifyingOtp: verifyingOtp ?? this.verifyingOtp,
      errorMsg: errorMsg ?? this.errorMsg,
      successMsg: successMsg ?? this.successMsg,
      emailError: emailError ?? this.emailError,
      verificationId: verificationId ?? this.verificationId,
      resendCountdown: resendCountdown ?? this.resendCountdown,
    );
  }
}
