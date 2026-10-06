// test/checkout/pasabay_batches_url_test.dart
// F15 (audit 2026-09-13). GET /api/pasabay/batches/:municipality/:barangay interpolated the two
// NAMES straight into the path.
//
// Spaces turned out to be safe — Dart's Uri.parse percent-encodes them on its own, so
// "Tuguegarao City" was never the problem the audit guessed it was. A SLASH is a different matter:
// it becomes a path separator, the route gains an extra segment and stops matching, and the
// repository's catch-all turns the 404 into a silent "no batches for this barangay".
//
// Two REAL production barangays carry one (PSGC `locations`):
//   • Camalaggoan/D Leaño
//   • Caddangan/Limbauan
// Pasabay was therefore unreachable for every customer in either, with no error shown.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/pasabay_repository.dart';

void main() {
  const base = 'https://api.trenda.ph';

  group('activeBatchesUri', () {
    test('keeps a slashed barangay in ONE path segment', () {
      final uri = activeBatchesUri(base, 'Tuguegarao City', 'Camalaggoan/D Leaño');

      expect(uri.pathSegments.last, 'Camalaggoan/D Leaño');
      // 3 fixed segments + municipality + barangay. The raw interpolation produced 6.
      expect(uri.pathSegments.length, 5);
    });

    test('the other live slashed barangay too', () {
      final uri = activeBatchesUri(base, 'Tuguegarao City', 'Caddangan/Limbauan');

      expect(uri.pathSegments.last, 'Caddangan/Limbauan');
      expect(uri.pathSegments.length, 5);
    });

    test('a space still round-trips (it always did)', () {
      final uri = activeBatchesUri(base, 'Tuguegarao City', 'Pallua Norte');

      expect(uri.pathSegments[3], 'Tuguegarao City');
      expect(uri.pathSegments[4], 'Pallua Norte');
    });

    test('non-ASCII names survive', () {
      final uri = activeBatchesUri(base, 'Tuguegarao City', 'Sto. Niño');

      expect(uri.pathSegments.last, 'Sto. Niño');
    });

    // `#` would otherwise become a fragment and `?` a query string, truncating the barangay.
    test('# and ? do not escape the path', () {
      final hash = activeBatchesUri(base, 'M', 'A#B');
      final query = activeBatchesUri(base, 'M', 'A?B');

      expect(hash.fragment, isEmpty);
      expect(hash.pathSegments.last, 'A#B');
      expect(query.query, isEmpty);
      expect(query.pathSegments.last, 'A?B');
    });

    test('points at the right endpoint', () {
      final uri = activeBatchesUri(base, 'Tuguegarao City', 'Centro');

      expect(uri.origin, 'https://api.trenda.ph');
      expect(uri.pathSegments.take(3).toList(), ['api', 'pasabay', 'batches']);
    });
  });
}
