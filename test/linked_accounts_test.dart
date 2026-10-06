// test/linked_accounts_test.dart
// The Linked Accounts sheet used to hardcode a Google row and a Phone row and
// fill them from the profile's email/phone — so an email-and-password user was
// told their Google account was linked when it never had been. These pin the
// real reading of Firebase's providerData.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/linked_accounts.dart';

({String providerId, String? email, String? phoneNumber}) _p(
  String id, {
  String? email,
  String? phone,
}) =>
    (providerId: id, email: email, phoneNumber: phone);

void main() {
  group('linkedAccounts', () {
    test('an email-and-password user is NOT shown as linked to Google', () {
      final rows = linkedAccounts([
        _p(kPasswordProvider, email: 'juan@example.ph'),
      ]);

      final google = rows.firstWhere((r) => r.providerId == kGoogleProvider);
      expect(google.isLinked, isFalse);
      expect(google.detail, isNull);

      final password =
          rows.firstWhere((r) => r.providerId == kPasswordProvider);
      expect(password.isLinked, isTrue);
      expect(password.detail, 'juan@example.ph');
    });

    test('a Google user shows Google linked and password not', () {
      final rows = linkedAccounts([
        _p(kGoogleProvider, email: 'juan@gmail.com'),
      ]);

      expect(
        rows.firstWhere((r) => r.providerId == kGoogleProvider).isLinked,
        isTrue,
      );
      expect(
        rows.firstWhere((r) => r.providerId == kPasswordProvider).isLinked,
        isFalse,
      );
    });

    test('a phone row shows the number, not an email', () {
      final rows = linkedAccounts([
        _p(kPhoneProvider, email: 'ignored@example.ph', phone: '+639171234567'),
      ]);

      final phone = rows.firstWhere((r) => r.providerId == kPhoneProvider);
      expect(phone.detail, '+639171234567');
    });

    test('always lists every method the app offers, linked or not', () {
      final rows = linkedAccounts(const []);

      expect(rows.length, 3);
      expect(rows.every((r) => !r.isLinked), isTrue);
      expect(
        rows.map((r) => r.providerId),
        [kPasswordProvider, kGoogleProvider, kPhoneProvider],
      );
    });

    test('a provider the app does not list is still shown, never hidden from '
        'the account owner', () {
      final rows = linkedAccounts([
        _p(kAppleProvider, email: 'juan@icloud.com'),
      ]);

      final apple = rows.firstWhere((r) => r.providerId == kAppleProvider);
      expect(apple.isLinked, isTrue);
      expect(apple.label, 'Apple');
      expect(rows.length, 4);
    });

    test('multiple linked methods all register', () {
      final rows = linkedAccounts([
        _p(kPasswordProvider, email: 'juan@example.ph'),
        _p(kGoogleProvider, email: 'juan@gmail.com'),
      ]);

      expect(rows.where((r) => r.isLinked).length, 2);
    });

    test('blank identifiers fall back to a plain Linked label', () {
      final rows = linkedAccounts([_p(kGoogleProvider, email: '  ')]);
      final google = rows.firstWhere((r) => r.providerId == kGoogleProvider);

      expect(google.isLinked, isTrue);
      expect(google.detail, isNull);
    });
  });

  group('linkedAccountsSummary', () {
    test('names only what is actually linked', () {
      final summary = linkedAccountsSummary(linkedAccounts([
        _p(kGoogleProvider, email: 'juan@gmail.com'),
      ]));

      expect(summary, 'Google');
      // The row used to read "Google, Phone" for everyone.
      expect(summary, isNot(contains('Phone')));
    });

    test('joins several', () {
      final summary = linkedAccountsSummary(linkedAccounts([
        _p(kPasswordProvider, email: 'juan@example.ph'),
        _p(kPhoneProvider, phone: '+639171234567'),
      ]));

      expect(summary, 'Email and password, Phone number');
    });

    test('says so when nothing is linked', () {
      expect(linkedAccountsSummary(linkedAccounts(const [])), 'None linked');
    });
  });

  group('linkedAccountLabel', () {
    test('names the methods in the customer\'s words', () {
      expect(linkedAccountLabel(kPasswordProvider), 'Email and password');
      expect(linkedAccountLabel(kGoogleProvider), 'Google');
      expect(linkedAccountLabel(kPhoneProvider), 'Phone number');
    });

    test('falls back to the raw id rather than dropping it', () {
      expect(linkedAccountLabel('github.com'), 'github.com');
    });
  });
}
