// trenda_shared/lib/services/offline_queue.dart
// ============================================================================
// OFFLINE QUEUE SERVICE
// Queues actions when offline and processes them when connection is restored
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';

/// Represents a pending action to be executed when online
class PendingAction {
  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  PendingAction({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionType': actionType,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
    id: json['id'] as String,
    actionType: json['actionType'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );

  PendingAction copyWith({int? retryCount}) => PendingAction(
    id: id,
    actionType: actionType,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Action handler function type
typedef ActionHandler = Future<bool> Function(PendingAction action);

/// Offline queue for storing and processing actions when connectivity is restored
class OfflineQueue {
  static const String _queueKey = 'offline_action_queue';
  static const int _maxRetries = 3;

  static final Map<String, ActionHandler> _handlers = {};
  static List<PendingAction> _queue = [];
  static bool _isProcessing = false;

  /// Initialize the queue from storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded.map((e) => PendingAction.fromJson(e)).toList();
        AppLogger.info(
          'Offline queue loaded: ${_queue.length} pending actions',
          'OfflineQueue',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to load offline queue', e);
      _queue = [];
    }
  }

  /// Register a handler for a specific action type
  static void registerHandler(String actionType, ActionHandler handler) {
    _handlers[actionType] = handler;
    AppLogger.debug('Registered handler for: $actionType', 'OfflineQueue');
  }

  /// Add an action to the queue
  static Future<void> enqueue(PendingAction action) async {
    _queue.add(action);
    await _saveQueue();
    AppLogger.info(
      'Action queued: ${action.actionType} (${action.id})',
      'OfflineQueue',
    );
  }

  /// Create and enqueue a new action
  static Future<void> addAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final action = PendingAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      actionType: actionType,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await enqueue(action);
  }

  /// Process all queued actions
  static Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    AppLogger.info(
      'Processing offline queue: ${_queue.length} actions',
      'OfflineQueue',
    );

    final List<PendingAction> completed = [];
    final List<PendingAction> failed = [];

    for (final action in List.from(_queue)) {
      final handler = _handlers[action.actionType];

      if (handler == null) {
        AppLogger.warning(
          'No handler for action type: ${action.actionType}',
          'OfflineQueue',
        );
        continue;
      }

      try {
        final success = await handler(action);

        if (success) {
          completed.add(action);
          AppLogger.info(
            'Action completed: ${action.actionType} (${action.id})',
            'OfflineQueue',
          );
        } else {
          // Increment retry count
          if (action.retryCount < _maxRetries) {
            final updated = action.copyWith(retryCount: action.retryCount + 1);
            final index = _queue.indexOf(action);
            if (index >= 0) {
              _queue[index] = updated;
            }
            AppLogger.warning(
              'Action failed, will retry (${action.retryCount + 1}/$_maxRetries): ${action.actionType}',
              'OfflineQueue',
            );
          } else {
            failed.add(action);
            AppLogger.error(
              'Action failed permanently after $_maxRetries retries: ${action.actionType}',
            );
          }
        }
      } catch (e) {
        AppLogger.error('Error processing action: ${action.actionType}', e);

        if (action.retryCount >= _maxRetries) {
          failed.add(action);
        }
      }
    }

    // Remove completed and permanently failed actions
    _queue.removeWhere((a) => completed.contains(a) || failed.contains(a));
    await _saveQueue();

    _isProcessing = false;
    AppLogger.info(
      'Queue processing complete: ${completed.length} completed, ${failed.length} failed, ${_queue.length} remaining',
      'OfflineQueue',
    );
  }

  /// Get the number of pending actions
  static int get pendingCount => _queue.length;

  /// Check if there are pending actions
  static bool get hasPendingActions => _queue.isNotEmpty;

  /// Get all pending actions
  static List<PendingAction> get pendingActions => List.unmodifiable(_queue);

  /// Clear all pending actions
  static Future<void> clear() async {
    _queue.clear();
    await _saveQueue();
    AppLogger.info('Offline queue cleared', 'OfflineQueue');
  }

  /// Remove a specific action
  static Future<void> remove(String actionId) async {
    _queue.removeWhere((a) => a.id == actionId);
    await _saveQueue();
  }

  /// Save queue to persistent storage
  static Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((a) => a.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      AppLogger.error('Failed to save offline queue', e);
    }
  }
}

// ============================================================================
// COMMON ACTION TYPES
// ============================================================================

/// Standard action types for the queue
class OfflineActionTypes {
  // Order actions
  static const String updateOrderStatus = 'order.updateStatus';
  static const String confirmOrder = 'order.confirm';
  static const String rejectOrder = 'order.reject';

  // Delivery actions
  static const String updateDeliveryStatus = 'delivery.updateStatus';
  static const String completeDelivery = 'delivery.complete';
  static const String updateRiderLocation = 'delivery.updateLocation';

  // Product actions
  static const String updateStock = 'product.updateStock';
  static const String updatePrice = 'product.updatePrice';
  static const String toggleAvailability = 'product.toggleAvailability';

  // Store actions
  static const String toggleStoreStatus = 'store.toggleStatus';
  static const String updateStoreHours = 'store.updateHours';
}
