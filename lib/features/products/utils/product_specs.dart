import 'package:trenda_shared/trenda_shared.dart';

/// Pure: build (label, value) rows for a listing's populated spec fields, using
/// the template's specFields for labels and order. Blank/missing values are
/// skipped, so a listing with no populated specs yields an empty list.
List<MapEntry<String, String>> specRows(
  ListingTemplate template,
  Map<String, dynamic> attributes,
) {
  final rows = <MapEntry<String, String>>[];
  for (final field in template.specFields) {
    final value = (attributes[field.key]?.toString() ?? '').trim();
    if (value.isNotEmpty) {
      rows.add(MapEntry(field.label, value));
    }
  }
  return rows;
}
