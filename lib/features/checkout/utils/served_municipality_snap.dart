// lib/features/checkout/utils/served_municipality_snap.dart
// Reverse-geocoding returns free text ("Tuguegarao"); the delivery-area rule compares
// names, so the GPS path must end on a SERVED PSGC name ("Tuguegarao City"). This only
// PRE-SELECTS — the customer confirms in the dropdown. No match → null (nothing picked).

String _base(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceFirst(RegExp(r'\s+city$'), '')
    .trim();

String? snapToServedMunicipality(String? geocoded, List<String> served) {
  final want = _base(geocoded ?? '');
  if (want.isEmpty) return null;
  for (final name in served) {
    if (_base(name) == want) return name;
  }
  return null;
}
