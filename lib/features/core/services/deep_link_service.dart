// lib/features/core/services/deep_link_service.dart
// ============================================================================
// DEEP LINK SERVICE - Handle Store QR Scans and App Links
// ============================================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider for deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});

/// Service for handling deep links from QR codes and external sources
class DeepLinkService {
  /// Parse a deep link URI and return navigation path
  ///
  /// Supported formats:
  /// - trenda://store/{vendorId}
  /// - https://trenda.app/store/{vendorId}
  /// - trenda://product/{productId}
  /// - trenda://order/{orderId}
  DeepLinkResult? parseDeepLink(Uri uri) {
    final scheme = uri.scheme;
    final host = uri.host;
    final pathSegments = uri.pathSegments;

    if (kDebugMode) {
      print('🔗 Parsing deep link: $uri');
      print('   Scheme: $scheme, Host: $host');
      print('   Path segments: $pathSegments');
    }

    // Handle custom scheme: trenda://
    if (scheme == 'trenda') {
      return _parseInternalLink(host, pathSegments, uri.queryParameters);
    }

    // Handle web URLs: https://trenda.app/...
    if ((scheme == 'https' || scheme == 'http') &&
        (host == 'trenda.app' || host == 'www.trenda.app')) {
      return _parseWebLink(pathSegments, uri.queryParameters);
    }

    return null;
  }

  DeepLinkResult? _parseInternalLink(
      String type, List<String> segments, Map<String, String> params) {
    switch (type) {
      case 'store':
        if (segments.isNotEmpty) {
          return DeepLinkResult(
            type: DeepLinkType.store,
            id: segments.first,
            params: params,
            routePath: '/vendor/${segments.first}',
          );
        }
        break;

      case 'product':
        if (segments.isNotEmpty) {
          return DeepLinkResult(
            type: DeepLinkType.product,
            id: segments.first,
            params: params,
            routePath: '/product/${segments.first}',
          );
        }
        break;

      case 'order':
        if (segments.isNotEmpty) {
          return DeepLinkResult(
            type: DeepLinkType.order,
            id: segments.first,
            params: params,
            routePath: '/orders/${segments.first}',
          );
        }
        break;

      case 'promo':
        if (segments.isNotEmpty) {
          return DeepLinkResult(
            type: DeepLinkType.promo,
            id: segments.first,
            params: params,
            routePath: '/promo/${segments.first}',
          );
        }
        break;

      case 'category':
        if (segments.isNotEmpty) {
          return DeepLinkResult(
            type: DeepLinkType.category,
            id: segments.first,
            params: params,
            routePath: '/category/${segments.first}',
          );
        }
        break;
    }

    return null;
  }

  DeepLinkResult? _parseWebLink(
      List<String> segments, Map<String, String> params) {
    if (segments.isEmpty) return null;

    final type = segments.first;
    final remainingSegments = segments.skip(1).toList();

    return _parseInternalLink(type, remainingSegments, params);
  }

  /// Navigate to a deep link destination
  void navigateToDeepLink(GoRouter router, DeepLinkResult result) {
    if (kDebugMode) {
      print('🚀 Navigating to: ${result.routePath}');
    }
    router.push(result.routePath);
  }
}

/// Result of parsing a deep link
class DeepLinkResult {
  final DeepLinkType type;
  final String id;
  final Map<String, String> params;
  final String routePath;

  DeepLinkResult({
    required this.type,
    required this.id,
    required this.params,
    required this.routePath,
  });

  @override
  String toString() => 'DeepLinkResult(type: $type, id: $id, path: $routePath)';
}

/// Types of deep links
enum DeepLinkType {
  store,
  product,
  order,
  promo,
  category,
}
