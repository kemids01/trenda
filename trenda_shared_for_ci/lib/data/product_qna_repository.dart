// trenda_shared/lib/data/product_qna_repository.dart
// Product Q&A repository — customer questions + vendor/admin answers

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/product_qna_model.dart';

class ProductQnaRepository extends BaseRepository {
  ProductQnaRepository({super.baseUrl});

  /// Get questions for a product (PUBLIC — guest-safe).
  ///
  /// `getIdToken()` throws when logged out, but this endpoint is public, so we
  /// tolerate the missing token and send an unauthenticated request.
  Future<List<ProductQna>> getProductQuestions(
    String productId, {
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      String? token;
      try {
        token = await getIdToken();
      } catch (_) {
        token = null;
      }

      final requestHeaders = token != null
          ? headers(token, json: false)
          : {'Accept': 'application/json'};

      final uri = Uri.parse('$baseUrl/api/qna/product/$productId').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http
          .get(uri, headers: requestHeaders)
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      return (body['data'] as List)
          .map((e) => ProductQna.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Ask a question about a product (auth required).
  Future<ProductQna> askQuestion(String productId, String question) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/qna/product/$productId');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'question': question}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductQna.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  /// Answer a question (auth — vendor/admin).
  Future<void> answerQuestion(String questionId, String text) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/qna/$questionId/answers');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'text': text}),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Vote an answer helpful (auth).
  Future<void> voteHelpful(String questionId, String answerId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/qna/$questionId/answers/$answerId/helpful',
      );

      final response = await http
          .post(uri, headers: headers(token))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Get pending (unanswered) questions for the vendor/admin (auth).
  Future<List<ProductQna>> getVendorPending({
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/qna/vendor/pending').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      return (body['data'] as List)
          .map((e) => ProductQna.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }
}
