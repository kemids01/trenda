// lib/features/search/providers/visual_search_provider.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/product_model.dart';

class ProductIdentification {
  final String productTitle;
  final String category;
  final String brand;
  final String primaryColor;
  final List<String> searchKeywords;
  final String visualSummary;

  const ProductIdentification({
    this.productTitle = '',
    this.category = '',
    this.brand = '',
    this.primaryColor = '',
    this.searchKeywords = const [],
    this.visualSummary = '',
  });

  factory ProductIdentification.fromJson(Map<String, dynamic> json) {
    return ProductIdentification(
      productTitle: json['productTitle']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      primaryColor: json['primaryColor']?.toString() ?? '',
      searchKeywords: (json['searchKeywords'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      visualSummary: json['visualSummary']?.toString() ?? '',
    );
  }
}

class VisualSearchResult {
  final ProductIdentification identification;
  final List<ProductModel> exactMatches;
  final List<ProductModel> similarProducts;

  const VisualSearchResult({
    this.identification = const ProductIdentification(),
    this.exactMatches = const [],
    this.similarProducts = const [],
  });

  bool get isEmpty => exactMatches.isEmpty && similarProducts.isEmpty;

  factory VisualSearchResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(Object? v) =>
        v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

    return VisualSearchResult(
      identification: ProductIdentification.fromJson(
        json['identification'] is Map<String, dynamic> ? json['identification'] : {},
      ),
      exactMatches: rows(json['exactMatches']).map(ProductModel.fromJson).toList(),
      similarProducts: rows(json['similarProducts']).map(ProductModel.fromJson).toList(),
    );
  }
}

class VisualSearchState {
  final bool isLoading;
  final String? error;
  final VisualSearchResult? result;

  const VisualSearchState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  VisualSearchState copyWith({
    bool? isLoading,
    String? error,
    VisualSearchResult? result,
  }) {
    return VisualSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

class VisualSearchNotifier extends StateNotifier<VisualSearchState> {
  VisualSearchNotifier() : super(const VisualSearchState());

  Future<void> searchWithBytes(Uint8List imageBytes, String mimeType) async {
    state = const VisualSearchState(isLoading: true);
    try {
      final base64Image = base64Encode(imageBytes);
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/products/visual-search');

      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'imageBase64': 'data:$mimeType;base64,$base64Image',
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final message = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Visual search failed (${response.statusCode})';
        state = VisualSearchState(error: message);
        return;
      }

      final body = jsonDecode(response.body);
      var data = body is Map<String, dynamic> ? body['data'] : null;

      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        data = data['data'];
      }

      if (data is! Map<String, dynamic>) {
        state = const VisualSearchState(error: 'Visual search returned unreadable data');
        return;
      }

      final result = VisualSearchResult.fromJson(data);
      state = VisualSearchState(result: result);
    } catch (e) {
      state = VisualSearchState(error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> searchWithFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final ext = imageFile.path.toLowerCase();
    final mimeType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
    await searchWithBytes(bytes, mimeType);
  }

  void reset() {
    state = const VisualSearchState();
  }
}

final visualSearchProvider = StateNotifierProvider<VisualSearchNotifier, VisualSearchState>((ref) {
  return VisualSearchNotifier();
});
