// trenda_shared/lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling authentication-related operations
class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// Send password reset email
  /// Returns true if successful, throws exception if failed
  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getReadableError(e.code);
    }
  }

  /// Change password for current user
  /// Requires user to be recently authenticated
  static Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Not logged in';
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign out and sign in again before changing password';
      }
      throw _getReadableError(e.code);
    }
  }

  /// Re-authenticate user with current password
  /// Required before changing password for security
  static Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw 'Not logged in';
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Current password is incorrect';
      }
      throw _getReadableError(e.code);
    }
  }

  /// Change password with re-authentication in one step
  static Future<void> changePasswordWithReauth({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await changePassword(newPassword);
  }

  /// Get current user email
  static String? get currentUserEmail => _auth.currentUser?.email;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Convert Firebase error codes to user-friendly messages
  static String _getReadableError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'requires-recent-login':
        return 'Please sign out and sign in again';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'invalid-email':
        return 'Invalid email address';
      default:
        return 'An error occurred: $code';
    }
  }
}
