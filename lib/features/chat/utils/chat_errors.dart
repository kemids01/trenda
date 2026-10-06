// lib/features/chat/utils/chat_errors.dart
// Turns a chat failure into a sentence a shopper can act on. The server's own
// message is used when it wrote one for people (403/404/400); transport noise
// ("ApiException: … (status: 404)", SocketException) never reaches the screen.
import 'dart:async';

import 'package:trenda_shared/trenda_shared.dart';

String friendlyChatError(Object error) {
  if (error is ApiException) {
    final code = error.statusCode ?? 0;
    if (code == 403) {
      return error.message.isNotEmpty
          ? error.message
          : 'This shop is not accepting messages right now.';
    }
    if (code == 404) {
      return 'We could not find this shop. It may have closed.';
    }
    if (code >= 400 && code < 500 && error.message.isNotEmpty) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
  if (error is AuthenticationException) {
    return 'Please sign in again to send messages.';
  }
  if (error is NetworkException || error is TimeoutException) {
    return 'No connection. Check your internet and try again.';
  }
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'No connection. Check your internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}
