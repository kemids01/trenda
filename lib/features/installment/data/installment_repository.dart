import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/models/installment_model.dart';

class InstallmentRepository {
  final String baseUrl;

  InstallmentRepository({required this.baseUrl});

  /// Get active installment plans for a specific product
  Future<List<InstallmentPlan>> getPlansForProduct(String productId,
      {String? token}) async {
    try {
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse('$baseUrl/api/installment/plans/$productId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('data')) {
          return (data['data'] as List)
              .map((e) => InstallmentPlan.fromJson(e))
              .toList();
        } else if (data is List) {
          return data.map((e) => InstallmentPlan.fromJson(e)).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching plans: $e');
    }
  }

  /// Submit a new installment application
  Future<InstallmentApplication> submitApplication(
      Map<String, dynamic> applicationData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/installment/applications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(applicationData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return InstallmentApplication.fromJson(data['data'] ?? data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to submit application');
      }
    } catch (e) {
      throw Exception('Error submitting application: $e');
    }
  }

  /// Get customer's own applications list
  Future<List<InstallmentApplication>> getMyApplications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/installment/applications'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('data')) {
          return (data['data'] as List)
              .map((e) => InstallmentApplication.fromJson(e))
              .toList();
        } else if (data is List) {
          return data.map((e) => InstallmentApplication.fromJson(e)).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load applications');
      }
    } catch (e) {
      throw Exception('Error fetching applications: $e');
    }
  }

  /// Get a single application's full details
  Future<InstallmentApplication> getApplicationDetails(
      String applicationId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/installment/applications/$applicationId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return InstallmentApplication.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Failed to load application details');
      }
    } catch (e) {
      throw Exception('Error fetching application details: $e');
    }
  }

  /// Save form data as draft
  Future<void> saveFormDraft(
      Map<String, dynamic> formData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/installment/customer/save-form'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(formData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save form draft');
      }
    } catch (e) {
      throw Exception('Error saving form draft: $e');
    }
  }

  /// Load previously saved form draft
  Future<Map<String, dynamic>?> getSavedFormDraft(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/installment/customer/saved-form'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // PAYMENTS (Post-Approval)
  // ===========================================================================

  /// Get payment schedule for an approved application
  Future<Map<String, dynamic>> getPaymentSchedule(
      String applicationId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/installment/payments/$applicationId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load payment schedule');
      }
    } catch (e) {
      throw Exception('Error fetching payment schedule: $e');
    }
  }

  /// Pay down payment via wallet
  Future<Map<String, dynamic>> payDownPayment(
      String applicationId, String token) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/installment/payments/$applicationId/pay-downpayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to process down payment');
      }
    } catch (e) {
      throw Exception('Error processing down payment: $e');
    }
  }

  /// Pay next installment via wallet
  Future<Map<String, dynamic>> payInstallment(
      String applicationId, String token,
      {int? installmentNumber}) async {
    try {
      final body = <String, dynamic>{};
      if (installmentNumber != null) {
        body['installmentNumber'] = installmentNumber;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/installment/payments/$applicationId/pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to process payment');
      }
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }
}
