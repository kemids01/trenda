// trenda_shared/lib/data/bundles_repository.dart
// Repository for product bundles

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/bundle_model.dart';

class BundlesRepository extends BaseRepository {
  BundlesRepository({super.baseUrl});

  /// Get all bundles
  Future<BundlesFetchResult> getBundles({
    int page = 1,
    int limit = 20,
    bool? activeOnly,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (activeOnly != null) 'active': activeOnly.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/bundles')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final bundles = (body['data'] as List)
          .map((b) => ProductBundle.fromJson(b))
          .toList();

      return BundlesFetchResult(
        bundles: bundles,
        total: body['pagination']?['total'] ?? bundles.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get bundle by ID
  Future<ProductBundle> getBundleById(String bundleId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles/$bundleId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductBundle.fromJson(body['data']);
    });
  }

  /// Create a new bundle
  Future<ProductBundle> createBundle(BundleRequest request) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles');

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(request.toJson()))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductBundle.fromJson(body['data']);
    });
  }

  /// Update a bundle
  Future<ProductBundle> updateBundle(
    String bundleId,
    BundleRequest request,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles/$bundleId');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(request.toJson()))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductBundle.fromJson(body['data']);
    });
  }

  /// Delete a bundle
  Future<void> deleteBundle(String bundleId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles/$bundleId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Toggle bundle status
  Future<ProductBundle> toggleBundleStatus(String bundleId, bool isActive) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles/$bundleId/status');

      final response = await http
          .patch(
            uri,
            headers: headers(token),
            body: jsonEncode({'isActive': isActive}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductBundle.fromJson(body['data']);
    });
  }

  /// Get bundle statistics
  Future<BundleStats> getBundleStats() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/bundles/stats');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return BundleStats.fromJson(body['data']);
    });
  }
}

class BundlesFetchResult {
  final List<ProductBundle> bundles;
  final int total;
  final int page;
  final int totalPages;

  BundlesFetchResult({
    required this.bundles,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
