// trenda_shared/lib/services/offline_queue_service.dart
// Offline action queue for syncing when connection is restored
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Types of actions that can be queued
enum OfflineActionType {
  updateOrderStatus,
  submitRating,
  updateLocation,
  completeDelivery,
}

/// Represents a queued offline action
class OfflineAction {
  final String id;
  final OfflineActionType type;
  final String endpoint;
  final String method; // POST, PUT, PATCH
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  OfflineAction({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'endpoint': endpoint,
    'method': method,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'],
    type: OfflineActionType.values.firstWhere((e) => e.name == json['type']),
    endpoint: json['endpoint'],
    method: json['method'],
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Service to manage offline action queue
class OfflineQueueService extends ChangeNotifier {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<OfflineAction> _queue = [];
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _syncTimer;

  List<OfflineAction> get pendingActions => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  /// Initialize the service
  void initialize() {
    // Start periodic sync check
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && _queue.isNotEmpty) {
        syncQueue();
      }
    });
    debugPrint('📡 OfflineQueueService initialized');
  }

  /// Update online status
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();

      if (online && _queue.isNotEmpty) {
        syncQueue();
      }
    }
  }

  /// Add action to queue
  void enqueue(OfflineAction action) {
    _queue.add(action);
    notifyListeners();
    debugPrint('📥 Queued offline action: ${action.type.name}');

    // Try to sync immediately if online
    if (_isOnline) {
      syncQueue();
    }
  }

  /// Queue an order status update
  void queueStatusUpdate({
    required String orderId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) {
    enqueue(
      OfflineAction(
        id: '${orderId}_status_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineActionType.updateOrderStatus,
        endpoint: '/api/orders/$orderId/status',
        method: 'PATCH',
        data: {'status': status, ...?additionalData},
      ),
    );
  }

  /// Queue a rating submission
  void queueRating({
    required String orderId,
    required int deliveryRating,
    required int productRating,
    String? comment,
    List<String>? tags,
  }) {
    enqueue(
      OfflineAction(
        id: '${orderId}_rating_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineActionType.submitRating,
        endpoint: '/api/ratings/delivery',
        method: 'POST',
        data: {
          'orderId': orderId,
          'deliveryRating': deliveryRating,
          'productRating': productRating,
          if (comment != null) 'comment': comment,
          if (tags != null) 'tags': tags,
        },
      ),
    );
  }

  /// Sync all queued actions
  Future<void> syncQueue() async {
    if (_isSyncing || _queue.isEmpty || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();
    debugPrint('🔄 Syncing ${_queue.length} offline actions...');

    final dio = Dio();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isSyncing = false;
      return;
    }

    final token = await user.getIdToken();
    final headers = {'Authorization': 'Bearer $token'};

    // Process queue in order
    final toRemove = <String>[];

    for (final action in _queue) {
      try {
        Response response;

        switch (action.method.toUpperCase()) {
          case 'POST':
            response = await dio.post(
              action.endpoint,
              data: action.data,
              options: Options(headers: headers),
            );
            break;
          case 'PUT':
            response = await dio.put(
              action.endpoint,
              data: action.data,
              options: Options(headers: headers),
            );
            break;
          case 'PATCH':
            response = await dio.patch(
              action.endpoint,
              data: action.data,
              options: Options(headers: headers),
            );
            break;
          default:
            continue;
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          toRemove.add(action.id);
          debugPrint('✅ Synced: ${action.type.name}');
        }
      } catch (e) {
        action.retryCount++;
        debugPrint(
          '❌ Sync failed (attempt ${action.retryCount}): ${action.type.name}',
        );

        // Remove after 5 failed attempts
        if (action.retryCount >= 5) {
          toRemove.add(action.id);
          debugPrint('🗑️ Removed after max retries: ${action.type.name}');
        }
      }
    }

    // Remove completed/failed actions
    _queue.removeWhere((a) => toRemove.contains(a.id));

    _isSyncing = false;
    notifyListeners();

    debugPrint('📊 Queue sync complete. Remaining: ${_queue.length}');
  }

  /// Clear all pending actions
  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
