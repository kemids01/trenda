// Fetches the public app-remote-config (GET /api/config/app). No auth — this must
// work before login (maintenance / force-update gate). Never throws; returns null
// on any failure so the app opens normally when the config can't be reached.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/app_runtime_config.dart';

class AppConfigRepository {
  static Future<AppRuntimeConfig?> fetch() async {
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/config/app');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        return AppRuntimeConfig.fromJson(data.cast<String, dynamic>());
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
