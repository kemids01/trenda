// lib/features/home/utils/profile_photo.dart
// The backend's User stores the photo as `photoUrl`. The app used to read (and
// write) `photoURL` — Firebase's spelling — so a saved photo, including the one
// copied from Google at sign-in, never loaded and the profile kept asking for one,
// and an uploaded photo was dropped by the server's allowed-fields list.

/// The field name the backend reads and writes.
const String kProfilePhotoField = 'photoUrl';

/// The stored photo URL from a `GET /api/users/:uid` body, or null when none.
/// Still accepts the legacy `photoURL` spelling in case an old response carries it.
String? storedPhotoUrl(Map<String, dynamic> data) {
  for (final key in const [kProfilePhotoField, 'photoURL']) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return null;
}
