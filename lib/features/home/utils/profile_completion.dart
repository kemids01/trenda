// lib/features/home/utils/profile_completion.dart
// What is still missing from an account, and where to go and fix it.
//
// The header used to compute a bare percentage inline and show it as a badge
// with nothing to press — the shopper was told they were 67% complete and left
// to guess which third was missing.

import 'package:flutter/foundation.dart';

/// One thing an account still needs.
@immutable
class ProfileGap {
  /// Short label, e.g. 'Phone number'.
  final String label;

  /// What tapping it should do, named so the caller can route it.
  final ProfileGapAction action;

  const ProfileGap(this.label, this.action);
}

// No email gap: customers sign in with Google only, which always supplies the
// address, and the profile does not let them edit it.
enum ProfileGapAction { name, phone, photo, address, birthday }

/// The state of an account, and the first thing worth fixing.
@immutable
class ProfileCompletion {
  final List<ProfileGap> gaps;
  final int completed;
  final int total;

  const ProfileCompletion({
    required this.gaps,
    required this.completed,
    required this.total,
  });

  int get percent => total == 0 ? 100 : ((completed / total) * 100).round();

  bool get isComplete => gaps.isEmpty;

  /// The gap to nudge about — the first unfilled field in priority order.
  /// Address comes before the cosmetic fields because nothing can be delivered
  /// without one.
  ProfileGap? get next => gaps.isEmpty ? null : gaps.first;
}

bool _filled(String? v) => v != null && v.trim().isNotEmpty;

/// Ordered by what actually blocks a purchase: an address and a phone number
/// are needed for a rider to arrive; a birthday is not.
ProfileCompletion profileCompletion({
  String? fullName,
  String? phone,
  String? photoUrl,
  int addressCount = 0,
  DateTime? birthday,
}) {
  final checks = <(bool, ProfileGap)>[
    (
      addressCount > 0,
      const ProfileGap('Delivery address', ProfileGapAction.address)
    ),
    (_filled(phone), const ProfileGap('Phone number', ProfileGapAction.phone)),
    (_filled(fullName), const ProfileGap('Your name', ProfileGapAction.name)),
    (
      _filled(photoUrl),
      const ProfileGap('Profile photo', ProfileGapAction.photo)
    ),
    (birthday != null, const ProfileGap('Birthday', ProfileGapAction.birthday)),
  ];

  return ProfileCompletion(
    gaps: [
      for (final (done, gap) in checks)
        if (!done) gap
    ],
    completed: checks.where((c) => c.$1).length,
    total: checks.length,
  );
}
