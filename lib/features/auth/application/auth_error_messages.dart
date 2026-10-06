import 'package:firebase_auth/firebase_auth.dart';

/// Maps an auth error (usually a FirebaseAuthException) to a short, user-friendly
/// message. Never returns a raw `[plugin/code]` string for known cases; falls back
/// to the exception's own message, then a generic line.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect.';
      case 'invalid-verification-id':
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Please request a new one.';
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'Please enter a valid phone number.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'This account is linked to a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please try another.';
      default:
        final m = error.message;
        if (m != null && m.trim().isNotEmpty) return m;
        return 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
