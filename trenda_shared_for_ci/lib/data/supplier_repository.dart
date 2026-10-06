// trenda_shared/lib/data/supplier_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_repository.dart';
import '../core/config.dart';
import '../models/supplier_models.dart';

class SupplierRepository extends BaseRepository {
  SupplierRepository({super.baseUrl});

  /// Fetch supplier catalog with filters
  Future<SupplierCatalogResult> fetchSupplierCatalog({
    int page = 1,
    int limit = 50,
    String? search,
    String? category,
    String? supplierId,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (supplierId != null) 'supplierId': supplierId,
      };

      final uri = Uri.parse('$baseUrl/api/supplier-catalog/catalog')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final products = (body['data'] as List)
          .map((e) => SupplierProduct.fromJson(e))
          .toList();

      return SupplierCatalogResult(
        products: products,
        total: body['pagination']?['total'] ?? products.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Fetch list of verified suppliers
  Future<List<SupplierInfo>> fetchSuppliers() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/supplier-catalog/suppliers');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      return (body['data'] as List)
          .map((e) => SupplierInfo.fromJson(e))
          .toList();
    });
  }

  /// Get detailed product information from supplier
  Future<SupplierProduct> getSupplierProductDetail(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/supplier-catalog/catalog/$productId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return SupplierProduct.fromJson(body['data']);
    });
  }

  /// Request quote from supplier
  Future<void> requestQuote({
    required String supplierId,
    required List<QuoteItem> products,
    String? message,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/supplier-catalog/quote-request');

      final response = await http.post(
        uri,
        headers: headers(token),
        body: jsonEncode({
          'supplierId': supplierId,
          'products': products.map((p) => p.toJson()).toList(),
          'message': message,
        }),
      ).timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Create supplier order
  Future<SupplierOrder> createSupplierOrder({
    required String supplierId,
    required List<SupplierOrderItem> items,
    required Map<String, dynamic> deliveryAddress,
    String? notes,
    required String paymentMethod,
    String? creditTerms,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/supplier-orders');

      final response = await http.post(
        uri,
        headers: headers(token),
        body: jsonEncode({
          'supplierId': supplierId,
          'items': items.map((i) => i.toJson()).toList(),
          'deliveryAddress': deliveryAddress,
          'notes': notes,
          'paymentMethod': paymentMethod,
          'creditTerms': creditTerms,
        }),
      ).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return SupplierOrder.fromJson(body['data']);
    });
  }

  /// Fetch vendor's supplier orders
  Future<SupplierOrdersResult> fetchVendorSupplierOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final uri = Uri.parse('$baseUrl/api/supplier-orders/vendor/orders')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final orders = (body['data'] as List)
          .map((e) => SupplierOrder.fromJson(e))
          .toList();

      return SupplierOrdersResult(
        orders: orders,
        total: body['pagination']?['total'] ?? orders.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Supplier-side: fetch the B2B orders vendors placed WITH this supplier.
  /// Returns raw maps (the endpoint enriches `vendor` into an object, so the typed
  /// SupplierOrder model — which expects a String vendor — cannot parse it).
  Future<List<Map<String, dynamic>>> fetchIncomingSupplierOrders({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };
      final uri = Uri.parse('$baseUrl/api/supplier-orders/supplier/orders')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  /// Advance / cancel a supplier order (forward-only lifecycle is enforced server-side).
  Future<Map<String, dynamic>> updateSupplierOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/supplier-orders/$orderId/status');

      final response = await http.put(
        uri,
        headers: headers(token),
        body: jsonEncode({'status': status, if (note != null) 'note': note}),
      ).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return Map<String, dynamic>.from(body['data'] ?? {});
    });
  }
}

// Result classes
class SupplierCatalogResult {
  final List<SupplierProduct> products;
  final int total;
  final int page;
  final int totalPages;

  SupplierCatalogResult({
    required this.products,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

class SupplierOrdersResult {
  final List<SupplierOrder> orders;
  final int total;
  final int page;
  final int totalPages;

  SupplierOrdersResult({
    required this.orders,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

// Helper classes
class QuoteItem {
  final String productId;
  final int quantity;
  final String? notes;

  QuoteItem({
    required this.productId,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    if (notes != null) 'notes': notes,
  };
}

class SupplierOrderItem {
  final String productId;
  final int quantity;

  SupplierOrderItem({
    required this.productId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}