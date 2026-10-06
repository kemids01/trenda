// trenda_shared/lib/core/api_result.dart
// ============================================================================
// API RESULT - Type-safe wrapper for API responses
// ============================================================================

/// Represents the result of an API call
/// Can be Success<T> or Failure
sealed class ApiResult<T> {
  const ApiResult();

  /// Returns true if this result is a success
  bool get isSuccess => this is Success<T>;

  /// Returns true if this result is a failure
  bool get isFailure => this is Failure<T>;

  /// Get the data if success, otherwise null
  T? get dataOrNull => switch (this) {
    Success<T>(data: final data) => data,
    Failure<T>() => null,
  };

  /// Get the error if failure, otherwise null
  ApiError? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final error) => error,
  };

  /// Transform the success data
  ApiResult<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(data: final data) => Success(transform(data)),
    Failure<T>(error: final error) => Failure(error),
  };

  /// Handle both success and failure cases
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiError error) failure,
  }) => switch (this) {
    Success<T>(data: final data) => success(data),
    Failure<T>(error: final error) => failure(error),
  };

  /// Handle both cases with optional handlers
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(ApiError error)? failure,
    required R Function() orElse,
  }) => switch (this) {
    Success<T>(data: final data) => success?.call(data) ?? orElse(),
    Failure<T>(error: final error) => failure?.call(error) ?? orElse(),
  };
}

/// Successful API result with data
class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);
}

/// Failed API result with error
class Failure<T> extends ApiResult<T> {
  final ApiError error;
  const Failure(this.error);
}

/// Represents an API error
class ApiError {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic originalError;

  const ApiError({
    required this.message,
    this.statusCode,
    this.code,
    this.originalError,
  });

  /// Factory for network errors
  factory ApiError.network([String? message]) => ApiError(
    message: message ?? 'Network connection failed',
    code: 'NETWORK_ERROR',
  );

  /// Factory for timeout errors
  factory ApiError.timeout([String? message]) =>
      ApiError(message: message ?? 'Request timed out', code: 'TIMEOUT');

  /// Factory for unauthorized errors
  factory ApiError.unauthorized([String? message]) => ApiError(
    message: message ?? 'Unauthorized access',
    statusCode: 401,
    code: 'UNAUTHORIZED',
  );

  /// Factory for forbidden errors
  factory ApiError.forbidden([String? message]) => ApiError(
    message: message ?? 'Access forbidden',
    statusCode: 403,
    code: 'FORBIDDEN',
  );

  /// Factory for not found errors
  factory ApiError.notFound([String? message]) => ApiError(
    message: message ?? 'Resource not found',
    statusCode: 404,
    code: 'NOT_FOUND',
  );

  /// Factory for server errors
  factory ApiError.server([String? message]) => ApiError(
    message: message ?? 'Server error occurred',
    statusCode: 500,
    code: 'SERVER_ERROR',
  );

  /// Factory for validation errors
  factory ApiError.validation(String message) =>
      ApiError(message: message, statusCode: 422, code: 'VALIDATION_ERROR');

  /// Factory from HTTP status code
  factory ApiError.fromStatusCode(int statusCode, [String? message]) {
    return switch (statusCode) {
      400 => ApiError(
        message: message ?? 'Bad request',
        statusCode: 400,
        code: 'BAD_REQUEST',
      ),
      401 => ApiError.unauthorized(message),
      403 => ApiError.forbidden(message),
      404 => ApiError.notFound(message),
      408 => ApiError.timeout(message),
      429 => ApiError(
        message: message ?? 'Too many requests',
        statusCode: 429,
        code: 'RATE_LIMITED',
      ),
      >= 500 => ApiError.server(message),
      _ => ApiError(
        message: message ?? 'Request failed',
        statusCode: statusCode,
      ),
    };
  }

  /// Parse error from exception
  factory ApiError.fromException(Object error) {
    if (error is ApiError) return error;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return ApiError.network();
    }

    if (errorString.contains('timeout')) {
      return ApiError.timeout();
    }

    return ApiError(message: error.toString(), originalError: error);
  }

  @override
  String toString() => 'ApiError($code: $message)';

  /// Convert to user-friendly message
  String get userMessage => switch (code) {
    'NETWORK_ERROR' => 'Please check your internet connection',
    'TIMEOUT' => 'The request took too long. Please try again.',
    'UNAUTHORIZED' => 'Please sign in to continue',
    'FORBIDDEN' => 'You don\'t have permission to do this',
    'NOT_FOUND' => 'The requested item was not found',
    'RATE_LIMITED' => 'Too many requests. Please wait a moment.',
    'SERVER_ERROR' => 'Something went wrong. Please try again later.',
    _ => message,
  };
}

/// Paginated API response wrapper
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final int totalItems;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalItems,
  });

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;

  /// Parse from common API response formats
  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson, {
    String dataKey = 'data',
  }) {
    final data = json[dataKey] ?? json['items'] ?? json['results'] ?? [];
    final items = (data as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedResult(
      items: items,
      page: json['page'] ?? json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? json['pages'] ?? 1,
      totalItems: json['total'] ?? json['totalItems'] ?? items.length,
    );
  }

  /// Create empty result
  factory PaginatedResult.empty() =>
      const PaginatedResult(items: [], page: 1, totalPages: 1, totalItems: 0);
}

/// Extension for easier JSON parsing
extension ApiResultHelpers on Map<String, dynamic> {
  /// Parse common API success response
  T getData<T>(String key, T Function(dynamic) parser) {
    final data = this['data'] ?? this[key] ?? this;
    return parser(data);
  }

  /// Get error message from common API error formats
  String get errorMessage {
    return this['message'] as String? ??
        this['error'] as String? ??
        (this['errors'] as List?)?.firstOrNull?.toString() ??
        'An error occurred';
  }
}
