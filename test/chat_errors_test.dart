import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/chat/utils/chat_errors.dart';
import 'package:trenda_shared/trenda_shared.dart';

void main() {
  group('friendlyChatError', () {
    test('uses the server sentence for a 403', () {
      expect(
        friendlyChatError(ApiException(
            'This shop does not have messaging enabled.',
            statusCode: 403)),
        'This shop does not have messaging enabled.',
      );
    });

    test('never shows transport noise', () {
      final text =
          friendlyChatError(ApiException('Resource not found', statusCode: 404));
      expect(text, isNot(contains('ApiException')));
      expect(text, isNot(contains('404')));
      expect(friendlyChatError(TimeoutException('x')), contains('connection'));
    });
  });
}
