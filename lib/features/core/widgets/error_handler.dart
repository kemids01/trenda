// lib/features/core/widgets/error_handler.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ErrorHandler {
  /// Map common errors to user-friendly messages
  static String getUserFriendlyMessage(Object error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }
    
    if (error is HttpException) {
      return 'Server error. Please try again later.';
    }
    
    if (error is FormatException) {
      return 'Invalid data format received from server.';
    }
    
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    
    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthError(error);
    }
    
    // Check for string error messages
    if (error is String) {
      if (error.toLowerCase().contains('connection refused')) {
        return 'Cannot connect to server. Please check if backend is running.';
      }
      if (error.toLowerCase().contains('unauthorized')) {
        return 'Session expired. Please login again.';
      }
      return error;
    }
    
    return error.toString();
  }
  
  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please login again to continue.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}

/// Reusable Error Widget
class ErrorDisplay extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? title;
  
  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
  });
  
  @override
  Widget build(BuildContext context) {
    final message = ErrorHandler.getUserFriendlyMessage(error);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(),
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'Oops! Something went wrong',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getErrorIcon() {
    if (error is SocketException || 
        error is TimeoutException ||
        error.toString().contains('connection')) {
      return Icons.wifi_off_rounded;
    }
    if (error is FirebaseAuthException) {
      return Icons.lock_outline;
    }
    return Icons.error_outline;
  }
}

/// Loading Widget with Message
class LoadingDisplay extends StatelessWidget {
  final String? message;
  
  const LoadingDisplay({super.key, this.message});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty State Widget
class EmptyDisplay extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  
  const EmptyDisplay({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel ?? 'Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Async Builder with Error Handling
class AsyncBuilder<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final String? emptyMessage;
  
  const AsyncBuilder({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.onRetry,
    this.loadingMessage,
    this.emptyMessage,
  });
  
  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (data) {
        // Handle empty lists
        if (data is List && data.isEmpty) {
          return EmptyDisplay(
            title: 'No Items',
            message: emptyMessage ?? 'Nothing to display',
            onAction: onRetry,
            actionLabel: 'Refresh',
          );
        }
        return builder(data);
      },
      loading: () => LoadingDisplay(message: loadingMessage),
      error: (error, _) => ErrorDisplay(
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}