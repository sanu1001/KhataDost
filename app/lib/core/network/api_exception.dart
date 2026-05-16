// app/lib/core/network/api_exception.dart

/// Single exception type thrown by every remote/mock datasource.
/// Replaces feature-local AuthException / DashboardException so error
/// surfacing is uniform across the app.
///
/// [statusCode] is optional and only set when the failure originated from
/// a server response — useful later if a feature needs to branch on
/// 4xx vs 5xx (e.g. show a retry button on 503 but not on 400).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
