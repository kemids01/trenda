// lib/features/checkout/logic/checkout_error_text.dart
// What the shopper is told when Place order fails. Every branch names the actual problem —
// "Checkout failed. Please try again." used to cover a signed-out session, a dropped
// connection, a host error page and a server rejection alike, so nobody could tell which.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// The reason in a non-201 create-order reply. The server's own `message` wins (it is
/// written for the shopper); failing that its `error`; failing that a line naming the
/// HTTP status, so even a host error page says what kind of failure it was.
String serverFailureText(int statusCode, String body) {
  final reason = _reasonOf(body);
  if (reason != null) return reason;
  if (statusCode == 401 || statusCode == 403) {
    return 'Your sign-in has expired. Please sign out and sign in again, then place the order.';
  }
  if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
    return 'The Trenda server is unavailable right now (HTTP $statusCode). '
        'Please wait a minute and try again.';
  }
  if (statusCode >= 500) {
    return 'The server hit an error while placing your order (HTTP $statusCode). '
        'Nothing was charged. Please try again.';
  }
  return 'The server refused the order (HTTP $statusCode) without saying why. '
      'Please try again or contact support.';
}

/// The shopper-facing text for anything thrown while placing an order.
String checkoutErrorText(Object error) {
  if (error is FirebaseAuthException) {
    if (error.code == 'network-request-failed') return _offline;
    return "We couldn't confirm your sign-in (${error.code}). "
        'Please sign out and sign in again.';
  }
  if (error is http.ClientException) return _offline;
  final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) return _offline;
  if (text == 'User not authenticated') {
    return 'You are signed out. Please sign in again to place your order.';
  }
  if (error is FormatException || error is TypeError) {
    return "We couldn't read the server's reply. Check My orders before trying again.";
  }
  if (text.contains('Insufficient stock')) {
    return 'Some items are out of stock. Please update your cart.';
  }
  return text.isEmpty ? 'Checkout failed. Please try again.' : 'Checkout failed: $text';
}

const _offline = 'No internet connection. Check your connection and try again.';

String? _reasonOf(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    for (final key in const ['message', 'error']) {
      final v = decoded[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  } catch (_) {
    // Not JSON — a host error page.
  }
  return null;
}
