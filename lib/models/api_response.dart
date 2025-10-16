/// Represents structured API responses for type safety
/// #todo: Use these instead of raw JSON parsing throughout the app

import 'package:cloud_firestore/cloud_firestore.dart';

/// Standard API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;
  final DateTime timestamp;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
    required this.timestamp,
  });

  /// Create successful response
  factory ApiResponse.success(T data, {int? statusCode}) {
    return ApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  /// Create error response
  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse<T>(
      success: false,
      error: error,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  /// Check if response has data
  bool get hasData => success && data != null;

  @override
  String toString() => success ? 'Success: $data' : 'Error: $error';
}

/// Firestore query result wrapper
/// #todo: Use this for consistent Firestore response handling
class FirestoreResult<T> {
  final List<T> items;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  const FirestoreResult({
    required this.items,
    this.hasMore = false,
    this.lastDocument,
    this.error,
  });

  /// Create successful result
  factory FirestoreResult.success(
    List<T> items, {
    bool hasMore = false,
    DocumentSnapshot? lastDocument,
  }) {
    return FirestoreResult(
      items: items,
      hasMore: hasMore,
      lastDocument: lastDocument,
    );
  }

  /// Create error result
  factory FirestoreResult.error(String error) {
    return FirestoreResult<T>(items: [], error: error);
  }

  /// Check if result has items
  bool get hasItems => items.isNotEmpty;

  /// Check if result is successful
  bool get isSuccess => error == null;

  @override
  String toString() => isSuccess
      ? 'FirestoreResult: ${items.length} items'
      : 'FirestoreError: $error';
}

/// User operation result
/// #todo: Use this for user authentication and profile operations
class UserOperationResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const UserOperationResult({required this.success, this.message, this.data});

  factory UserOperationResult.success({
    String? message,
    Map<String, dynamic>? data,
  }) {
    return UserOperationResult(success: true, message: message, data: data);
  }

  factory UserOperationResult.failure(String message) {
    return UserOperationResult(success: false, message: message);
  }

  @override
  String toString() => success ? 'Success: $message' : 'Failure: $message';
}

/// Cache operation result
/// #todo: Use this for cache operations instead of raw boolean returns
class CacheResult<T> {
  final bool hit; // true if data was found in cache
  final T? data;
  final DateTime? cachedAt;
  final bool expired;

  const CacheResult({
    required this.hit,
    this.data,
    this.cachedAt,
    this.expired = false,
  });

  /// Create cache hit result
  factory CacheResult.hit(T data, DateTime cachedAt, bool expired) {
    return CacheResult(
      hit: true,
      data: data,
      cachedAt: cachedAt,
      expired: expired,
    );
  }

  /// Create cache miss result
  factory CacheResult.miss() {
    return CacheResult<T>(hit: false);
  }

  /// Check if cache result is valid (hit and not expired)
  bool get isValid => hit && !expired && data != null;

  @override
  String toString() =>
      hit ? 'CacheHit: ${expired ? 'expired' : 'valid'}' : 'CacheMiss';
}
