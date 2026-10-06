// Cities a customer may LIVE in (served ∪ neighbours) and their barangays —
// GET /api/municipalities/deliverable[/barangays]. The BROWSE filter keeps using the
// served list (availableMunicipalitiesProvider); only ADDRESS pickers use this.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/trenda_shared.dart' show MunicipalityModel, AppConfig;

List<MunicipalityModel> parseDeliverable(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is! List) return const [];
  var i = 0;
  return [
    for (final d in data)
      if (d is Map && (d['name']?.toString() ?? '').isNotEmpty)
        MunicipalityModel.fromJson({
          '_id': d['psgcCode']?.toString() ?? d['name'].toString(),
          'name': d['name'].toString(),
          'isActive': true,
          'order': i++, // keep the server order: served first, then neighbours
        }),
  ];
}

List<String> parseBarangayNames(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is! List) return const [];
  return [
    for (final b in data)
      if (b is Map && (b['name']?.toString() ?? '').isNotEmpty) b['name'].toString(),
  ];
}

class DeliverableRepository {
  Future<List<MunicipalityModel>> municipalities() async {
    final res = await http
        .get(Uri.parse('${AppConfig.backendBaseUrl}/api/municipalities/deliverable'))
        .timeout(AppConfig.connectTimeout);
    if (res.statusCode != 200) throw Exception('deliverable ${res.statusCode}');
    return parseDeliverable(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// Empty for a city that isn't deliverable (404) — never throws on that.
  Future<List<String>> barangays(String city) async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/municipalities/deliverable/barangays')
        .replace(queryParameters: {'municipality': city});
    final res = await http.get(uri).timeout(AppConfig.connectTimeout);
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) throw Exception('deliverable barangays ${res.statusCode}');
    return parseBarangayNames(Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }
}
