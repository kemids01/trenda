// trenda_shared/lib/data/vendor_address_repository.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config.dart';
import 'base_repository.dart';
import '../models/address_model.dart';

class VendorAddressRepository extends BaseRepository {
  VendorAddressRepository({super.baseUrl});

  /// Get vendor's main address
  Future<AddressModel?> getVendorAddress() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/address');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'];

      if (data['mainAddress'] == null) {
        return null;
      }

      return AddressModel.fromJson(data['mainAddress']);
    });
  }

  /// Update vendor's main address
  Future<AddressModel> updateVendorAddress(AddressModel address) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/address');

      final response = await http
          .put(
            uri,
            headers: headers(token, json: true),
            body: jsonEncode(address.toJson()),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return AddressModel.fromJson(body['data']['mainAddress']);
    });
  }

  /// Get address completion status
  Future<Map<String, dynamic>> getAddressCompletionStatus() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/address/status');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data'] as Map<String, dynamic>;
    });
  }
}
