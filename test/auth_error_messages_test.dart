import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/auth/application/auth_error_messages.dart';

FirebaseAuthException _e(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  test('credential errors collapse to one friendly message', () {
    const expected = 'Incorrect email or password.';
    expect(friendlyAuthError(_e('invalid-credential')), expected);
    expect(friendlyAuthError(_e('wrong-password')), expected);
    expect(friendlyAuthError(_e('user-not-found')), expected);
  });

  test('common codes map to friendly text', () {
    expect(friendlyAuthError(_e('invalid-email')), 'Please enter a valid email address.');
    expect(friendlyAuthError(_e('too-many-requests')),
        'Too many attempts. Please wait a moment and try again.');
    expect(friendlyAuthError(_e('network-request-failed')),
        'Network error. Check your connection and try again.');
    expect(friendlyAuthError(_e('email-already-in-use')),
        'An account already exists for this email.');
    expect(friendlyAuthError(_e('weak-password')),
        'Password is too weak (use at least 6 characters).');
    expect(friendlyAuthError(_e('invalid-verification-code')),
        'The code you entered is incorrect.');
    expect(friendlyAuthError(_e('session-expired')),
        'The code expired. Please request a new one.');
    expect(friendlyAuthError(_e('invalid-phone-number')),
        'Please enter a valid phone number.');
  });

  test('unknown Firebase code with a message returns the message', () {
    expect(friendlyAuthError(_e('some-new-code', 'Custom backend message')),
        'Custom backend message');
  });

  test('unknown Firebase code without message returns generic Firebase fallback', () {
    expect(friendlyAuthError(_e('some-new-code')),
        'Authentication failed. Please try again.');
  });

  test('non-Firebase error returns generic default (no raw text leak)', () {
    final msg = friendlyAuthError(Exception('boom secret detail'));
    expect(msg, 'Something went wrong. Please try again.');
    expect(msg.contains('boom'), isFalse);
  });
}
