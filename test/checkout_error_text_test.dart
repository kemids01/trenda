import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_frontend/features/checkout/logic/checkout_error_text.dart';

void main() {
  group('serverFailureText', () {
    test("uses the server's message", () {
      expect(serverFailureText(400, '{"success":false,"message":"Stock unavailable for: Vacuume"}'),
          'Stock unavailable for: Vacuume');
    });

    test('falls back to the error field', () {
      expect(serverFailureText(500, '{"error":"x is not defined"}'), 'x is not defined');
    });

    test('names the status when the body is a host error page', () {
      expect(serverFailureText(502, '<html>Bad Gateway</html>'), contains('HTTP 502'));
      expect(serverFailureText(500, ''), contains('HTTP 500'));
      expect(serverFailureText(418, '{"message":"  "}'), contains('HTTP 418'));
    });

    test('a reason-less 401 says the sign-in expired', () {
      expect(serverFailureText(401, ''), contains('sign-in has expired'));
    });
  });

  group('checkoutErrorText', () {
    test('signed out', () {
      expect(checkoutErrorText(Exception('User not authenticated')), contains('signed out'));
    });

    test('offline', () {
      expect(checkoutErrorText(http.ClientException('Failed host lookup')),
          contains('No internet'));
      expect(checkoutErrorText(FirebaseAuthException(code: 'network-request-failed')),
          contains('No internet'));
    });

    test('auth token failure names its code', () {
      expect(checkoutErrorText(FirebaseAuthException(code: 'user-token-expired')),
          contains('user-token-expired'));
    });

    test('anything else shows the error itself, never a bare "try again"', () {
      expect(checkoutErrorText(StateError('boom')), 'Checkout failed: Bad state: boom');
    });
  });
}
