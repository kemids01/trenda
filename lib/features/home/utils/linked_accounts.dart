// lib/features/home/utils/linked_accounts.dart
// Which sign-in methods are actually attached to this account.
//
// The Linked Accounts sheet used to hardcode a Google row and a Phone row and
// fill their subtitles from the profile's email/phone — so an email-and-password
// user who had never touched Google was told their Google account was linked,
// and the settings row underneath always read "Google, Phone".
//
// Firebase already knows the truth: User.providerData. This turns it into
// something a list can render, without importing Flutter.

import 'package:flutter/foundation.dart';

/// Firebase provider ids this app can sign in with.
const String kPasswordProvider = 'password';
const String kGoogleProvider = 'google.com';
const String kPhoneProvider = 'phone';
const String kFacebookProvider = 'facebook.com';
const String kAppleProvider = 'apple.com';

@immutable
class LinkedAccount {
  /// The Firebase provider id.
  final String providerId;

  /// What the customer calls it.
  final String label;

  /// The identifier attached through that provider, when there is one.
  final String? detail;

  final bool isLinked;

  const LinkedAccount({
    required this.providerId,
    required this.label,
    required this.isLinked,
    this.detail,
  });
}

String linkedAccountLabel(String providerId) {
  switch (providerId) {
    case kPasswordProvider:
      return 'Email and password';
    case kGoogleProvider:
      return 'Google';
    case kPhoneProvider:
      return 'Phone number';
    case kFacebookProvider:
      return 'Facebook';
    case kAppleProvider:
      return 'Apple';
    default:
      return providerId;
  }
}

/// One row per sign-in method this app offers, each saying whether it is really
/// attached. [providers] is `(providerId, email, phoneNumber)` per entry, taken
/// straight from `FirebaseAuth.instance.currentUser!.providerData`.
///
/// Methods the account does use but this app does not list are appended, so a
/// linked provider is never hidden from the person who owns the account.
List<LinkedAccount> linkedAccounts(
  List<({String providerId, String? email, String? phoneNumber})> providers,
) {
  const offered = [
    kPasswordProvider,
    kGoogleProvider,
    kFacebookProvider,
    kPhoneProvider
  ];

  String? detailFor(({String providerId, String? email, String? phoneNumber}) p) {
    final phone = p.phoneNumber?.trim();
    final email = p.email?.trim();
    if (p.providerId == kPhoneProvider) {
      return (phone != null && phone.isNotEmpty) ? phone : null;
    }
    if (email != null && email.isNotEmpty) return email;
    return (phone != null && phone.isNotEmpty) ? phone : null;
  }

  final rows = <LinkedAccount>[];

  for (final id in offered) {
    final match = providers.where((p) => p.providerId == id).toList();
    rows.add(LinkedAccount(
      providerId: id,
      label: linkedAccountLabel(id),
      isLinked: match.isNotEmpty,
      detail: match.isEmpty ? null : detailFor(match.first),
    ));
  }

  for (final p in providers) {
    if (offered.contains(p.providerId)) continue;
    if (rows.any((r) => r.providerId == p.providerId)) continue;
    rows.add(LinkedAccount(
      providerId: p.providerId,
      label: linkedAccountLabel(p.providerId),
      isLinked: true,
      detail: detailFor(p),
    ));
  }

  return rows;
}

/// 'Google, Phone number' — what the settings row should say instead of a
/// hardcoded list of everything the app supports.
String linkedAccountsSummary(List<LinkedAccount> accounts) {
  final linked = accounts.where((a) => a.isLinked).map((a) => a.label).toList();
  if (linked.isEmpty) return 'None linked';
  return linked.join(', ');
}
