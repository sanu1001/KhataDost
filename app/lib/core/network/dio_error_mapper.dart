// app/lib/core/network/dio_error_mapper.dart

import 'package:dio/dio.dart';

/// Maps a [DioException] to a user-facing message string.
///
/// Strategy:
///   1. If the server returned a JSON body with `error` or `message`, use it.
///   2. Otherwise, fall back to a category-specific generic message.
///
/// Pure function so it can be unit tested without a Dio instance.
String mapDioError(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map) {
      final fromBody = (data['error'] as String?) ?? (data['message'] as String?);
      if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    }
  } catch (_) {
    // fall through to fallback
  }
  return _fallback(e);
}

String _fallback(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout =>
      'Connection timed out. Please try again.',
    DioExceptionType.connectionError => 'No internet connection.',
    _ => 'Something went wrong. Please try again.',
  };
}
