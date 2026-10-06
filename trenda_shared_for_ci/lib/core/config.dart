// ============================================================================
// FILE: trenda_shared/lib/core/config.dart - ENHANCED
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class AppConfig {
  // ✅ Smart backend URL with multiple fallbacks
  static String get backendBaseUrl {
    // 1. Environment variable (highest priority)
    const envUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // 2. Runtime override
    if (_overrideUrl != null) return _overrideUrl!;

    // 3. Platform-specific defaults
    // 3. Platform-specific defaults
    if (kIsWeb) {
      // Web uses localhost for development, Render URL for production
      return const String.fromEnvironment(
        'PROD_URL',
        defaultValue:
            'https://trenda-backend.onrender.com', // User explicitly requested Render backend
      );
    }

    // 4. Mobile defaults - use Render URL for physical device testing
    if (kDebugMode) {
      return 'https://trenda-backend.onrender.com';
    }

    // Production URL (for mobile release builds)
    return const String.fromEnvironment(
      'PROD_URL',
      defaultValue: 'https://trenda-backend.onrender.com',
    );
  }

  // ✅ Runtime URL override
  static String? _overrideUrl;

  static void setBackendUrl(String url) {
    _overrideUrl = url;
    print('🔧 Backend URL overridden to: $url');
  }

  static void resetBackendUrl() {
    _overrideUrl = null;
    print('🔄 Backend URL reset to default');
  }

  // Timeouts (increased for Render cold start - free tier sleeps after inactivity)
  static const connectTimeout = Duration(seconds: 90);
  static const receiveTimeout = Duration(seconds: 90);
  static const shortTimeout = Duration(seconds: 30);

  // Retry configuration
  static const maxRetries = 3;
  static const retryDelay = Duration(seconds: 2);

  // Pagination
  static const defaultPageSize = 20;
  static const maxPageSize = 100;

  // Cache
  static const cacheExpiration = Duration(minutes: 15);
  static const maxCacheAge = Duration(hours: 24);

  // Categories
  static const List<String> productCategories = [
    // Standard physical
    'Electronics',
    'Fashion',
    'Home & Garden',
    'Beauty',
    'Sports',
    'Books',
    'Toys',
    'Health',
    'Automotive',
    // Fresh / by-weight
    'Meat & Seafood',
    'Fresh Produce',
    'Food & Beverages',
    // Cooked food from restaurants — what the customer Food tab lists.
    'Restaurant Food',
    // Big-ticket
    'Vehicles',
    'Appliances',
    'Furniture',
    // Services
    'Services',
    'Other',
  ];
  // Order statuses
  static const orderStatuses = [
    'pending',
    'confirmed',
    'processing',
    'ready_to_ship',
    'shipped',
    'out_for_delivery',
    'delivered',
    'cancelled',
    'refunded',
    'failed',
  ];

  // User roles
  static const userRoles = [
    'customer',
    'vendor',
    'supplier',
    'delivery',
    'staff',
    'admin',
  ];

  // ✅ Enhanced connection check
  static Future<ConnectionCheckResult> checkBackendConnection({
    bool verbose = false,
  }) async {
    final url = backendBaseUrl;

    if (verbose) {
      print('\n🔍 === BACKEND CONNECTION CHECK ===');
      print('🔗 Testing URL: $url');
      print('🌐 Environment: ${kDebugMode ? "DEBUG" : "RELEASE"}');
      if (!kIsWeb) {
        print('📱 Platform: ${Platform.operatingSystem}');
      }
    }

    try {
      final uri = Uri.parse('$url/health');
      final response = await http.get(uri).timeout(shortTimeout);

      if (response.statusCode == 200) {
        if (verbose) {
          print('✅ Connection successful!');
          print('📊 Response: ${response.body.substring(0, 100)}...');
          print('=' * 40);
        }
        return ConnectionCheckResult(
          success: true,
          statusCode: response.statusCode,
          message: 'Connected successfully',
        );
      } else {
        if (verbose) {
          print('⚠️ Unexpected status: ${response.statusCode}');
          print('=' * 40);
        }
        return ConnectionCheckResult(
          success: false,
          statusCode: response.statusCode,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } catch (e) {
      if (verbose) {
        print('❌ Connection failed: $e');
        print('\n💡 Troubleshooting:');
        print('1. Check if backend server is running');
        print('2. Verify the URL: $url');
        print('3. Check firewall/antivirus settings');
        print('=' * 40 + '\n');
      }

      return ConnectionCheckResult(
        success: false,
        error: e.toString(),
        message: _getConnectionErrorMessage(e),
      );
    }
  }

  static String _getConnectionErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout')) {
      return 'Connection timeout - Server not responding';
    } else if (errorStr.contains('connection refused')) {
      return 'Connection refused - Server not running';
    } else if (errorStr.contains('failed host lookup')) {
      return 'Cannot resolve hostname - Check URL';
    } else if (errorStr.contains('network is unreachable')) {
      return 'No internet connection';
    } else if (errorStr.contains('socketexception')) {
      return 'Network error - Check connection';
    } else {
      return 'Connection failed: ${error.toString().split(':').first}';
    }
  }
}

class ConnectionCheckResult {
  final bool success;
  final int? statusCode;
  final String message;
  final String? error;

  ConnectionCheckResult({
    required this.success,
    this.statusCode,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    return 'ConnectionCheckResult(success: $success, message: $message)';
  }
}
