// trenda_shared/lib/services/websocket_service.dart
// Real-time Socket.IO sync service for all apps
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ============================================================================
// WEBSOCKET STATE
// ============================================================================

enum WebSocketStatus { disconnected, connecting, connected, error }

class WebSocketState {
  final WebSocketStatus status;
  final String? lastError;
  final Map<String, dynamic>? lastMessage;
  final DateTime? lastMessageTime;

  const WebSocketState({
    this.status = WebSocketStatus.disconnected,
    this.lastError,
    this.lastMessage,
    this.lastMessageTime,
  });

  WebSocketState copyWith({
    WebSocketStatus? status,
    String? lastError,
    Map<String, dynamic>? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return WebSocketState(
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  bool get isConnected => status == WebSocketStatus.connected;
}

// ============================================================================
// WEBSOCKET EVENT CALLBACK TYPE
// ============================================================================

typedef WebSocketEventCallback =
    void Function(String event, Map<String, dynamic> data);

// ============================================================================
// WEBSOCKET NOTIFIER (SOCKET.IO CLIENT)
// ============================================================================

class WebSocketNotifier extends StateNotifier<WebSocketState> {
  IO.Socket? _socket;
  String? _baseUrl;
  String? _userId;
  String? _userRole;
  String? _authToken;
  String? _appSource;
  int _reconnectAttempts = 0;
  Timer? _tokenRefreshTimer;

  // Callback to get fresh token (set by app-specific providers)
  Future<String?> Function()? onTokenRefreshNeeded;

  // Event callbacks
  final List<WebSocketEventCallback> _eventListeners = [];

  WebSocketNotifier() : super(const WebSocketState());

  // Expose connection info for debugging/monitoring
  String? get baseUrl => _baseUrl;
  String? get authToken => _authToken;
  int get reconnectAttempts => _reconnectAttempts;

  /// Connect to Socket.IO server
  Future<void> connect({
    required String baseUrl,
    required String userId,
    required String userRole,
    String? authToken,
    String? appSource,
  }) async {
    _baseUrl = baseUrl;
    _userId = userId;
    _userRole = userRole;
    _authToken = authToken;
    _appSource = appSource;

    if (state.isConnected) {
      print('📡 Socket.IO already connected');
      return;
    }

    state = state.copyWith(status: WebSocketStatus.connecting);

    try {
      print('📡 Connecting to Socket.IO: $baseUrl');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({
              'token': authToken,
              if (appSource != null) 'appSource': appSource,
            })
            .setQuery({'userId': userId, 'role': userRole})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(3000)
            .setReconnectionDelayMax(30000)
            .build(),
      );

      _setupEventListeners();

      // ✅ Start token refresh timer (refresh every 50 minutes - tokens expire in 60)
      _startTokenRefreshTimer();
    } catch (e) {
      print('❌ Socket.IO connection error: $e');
      state = state.copyWith(
        status: WebSocketStatus.error,
        lastError: e.toString(),
      );
    }
  }

  /// Start timer to proactively refresh token before it expires
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    // Refresh token every 50 minutes (Firebase tokens expire in 60 minutes)
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
      print('🔄 Proactively refreshing WebSocket auth token...');
      await _refreshAndReconnect();
    });
  }

  /// Refresh token and reconnect
  Future<void> _refreshAndReconnect() async {
    if (onTokenRefreshNeeded != null) {
      try {
        final freshToken = await onTokenRefreshNeeded!();
        if (freshToken != null && freshToken != _authToken) {
          updateAuthToken(freshToken);
        }
      } catch (e) {
        print('❌ Failed to refresh token: $e');
      }
    }
  }

  void _setupEventListeners() {
    _socket?.onConnect((_) {
      print('✅ Socket.IO connected');
      state = state.copyWith(status: WebSocketStatus.connected);
      _reconnectAttempts = 0;

      // Join user-specific room
      _socket?.emit('join', {'room': 'user:$_userId', 'role': _userRole});
    });

    _socket?.onConnecting((_) {
      print('🔄 Socket.IO connecting...');
      state = state.copyWith(status: WebSocketStatus.connecting);
    });

    _socket?.onReconnect((_) {
      if (_reconnectAttempts <= 1) print('🔄 Socket.IO reconnected');
      state = state.copyWith(status: WebSocketStatus.connected);
    });

    _socket?.onReconnectAttempt((attempt) {
      if (attempt == 1) print('🔄 Socket.IO reconnecting...');
      _reconnectAttempts = attempt as int;
    });

    _socket?.onReconnectFailed((_) {
      print('❌ Socket.IO reconnect failed after max attempts');
      state = state.copyWith(
        status: WebSocketStatus.error,
        lastError: 'Reconnection failed',
      );
    });

    _socket?.onDisconnect((reason) {
      print('📴 Socket.IO disconnected: $reason');
      state = state.copyWith(status: WebSocketStatus.disconnected);
    });

    _socket?.onConnectError((error) {
      print('❌ Socket.IO connect error: $error');
      state = state.copyWith(
        status: WebSocketStatus.error,
        lastError: error.toString(),
      );

      // ✅ If error is auth-related, refresh token and retry
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('token') ||
          errorStr.contains('auth') ||
          errorStr.contains('expired')) {
        print('🔄 Auth error detected, attempting token refresh...');
        _refreshAndReconnect();
      }
    });

    _socket?.onError((error) {
      print('❌ Socket.IO error: $error');
      state = state.copyWith(
        status: WebSocketStatus.error,
        lastError: error.toString(),
      );
    });

    // Listen for custom events
    _socket?.onAny((event, data) {
      print('📨 Socket.IO event: $event');

      final payload = data is Map<String, dynamic>
          ? data
          : (data is List && data.isNotEmpty && data[0] is Map<String, dynamic>)
          ? data[0] as Map<String, dynamic>
          : <String, dynamic>{};

      state = state.copyWith(
        lastMessage: {'event': event, 'data': payload},
        lastMessageTime: DateTime.now(),
      );

      // Notify all event listeners
      for (final listener in _eventListeners) {
        listener(event, payload);
      }
    });

    // Specific event handlers for orders
    _socket?.on('order:new', (data) {
      _handleOrderEvent('order:new', data);
    });

    _socket?.on('order:update', (data) {
      _handleOrderEvent('order:update', data);
    });

    _socket?.on('order:status_changed', (data) {
      _handleOrderEvent('order:status_changed', data);
    });

    _socket?.on('dashboard:update', (data) {
      _handleEvent('dashboard:update', data);
    });

    _socket?.on('product:update', (data) {
      _handleEvent('product:update', data);
    });

    _socket?.on('pong', (data) {
      print('🏓 Pong received: $data');
    });
  }

  void _handleOrderEvent(String event, dynamic data) {
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    for (final listener in _eventListeners) {
      listener(event, payload);
    }
  }

  void _handleEvent(String event, dynamic data) {
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    for (final listener in _eventListeners) {
      listener(event, payload);
    }
  }

  /// Emit event to server
  void emit(String event, [dynamic data]) {
    if (_socket != null && state.isConnected) {
      _socket!.emit(event, data);
    }
  }

  /// Update auth token and reconnect
  void updateAuthToken(String? newToken) {
    if (newToken == null || newToken == _authToken) return;

    _authToken = newToken;
    print('🔄 Updating auth token and reconnecting...');

    // Disconnect and reconnect with new token
    if (_baseUrl != null && _userId != null && _userRole != null) {
      disconnect();
      connect(
        baseUrl: _baseUrl!,
        userId: _userId!,
        userRole: _userRole!,
        authToken: newToken,
        appSource: _appSource,
      );
    }
  }

  /// Subscribe to dashboard updates
  void subscribeToDashboard() {
    emit('subscribe:dashboard');
  }

  /// Subscribe to order updates
  void subscribeToOrder(String orderId) {
    emit('subscribe:order', orderId);
  }

  /// Unsubscribe from order updates
  void unsubscribeFromOrder(String orderId) {
    emit('unsubscribe:order', orderId);
  }

  /// Add event listener for Socket.IO messages
  void addEventCallback(WebSocketEventCallback listener) {
    _eventListeners.add(listener);
  }

  /// Remove event listener
  void removeEventCallback(WebSocketEventCallback listener) {
    _eventListeners.remove(listener);
  }

  /// Disconnect from Socket.IO
  void disconnect() {
    print('📴 Disconnecting Socket.IO');
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _socket?.dispose();
    _socket = null;
    state = const WebSocketState();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    disconnect();
    super.dispose();
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final webSocketProvider =
    StateNotifierProvider<WebSocketNotifier, WebSocketState>(
      (ref) => WebSocketNotifier(),
    );

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/// Setup order status listener - call this in your screens
void setupOrderStatusRefresh(
  WidgetRef ref,
  void Function(String orderId, String newStatus) onStatusChange,
) {
  ref.read(webSocketProvider.notifier).addEventCallback((event, data) {
    if (event == 'order:status_changed') {
      final orderId = data['orderId'] as String?;
      final newStatus = data['newStatus'] as String?;
      if (orderId != null && newStatus != null) {
        onStatusChange(orderId, newStatus);
      }
    }
  });
}
