// app/lib/core/network/dio_client.dart

import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';

/// Wraps a single shared [Dio] instance.
///
/// Responsibilities:
///   1. Attach the JWT to every outbound request (request interceptor).
///   2. Detect a 401 on an authenticated request and notify the app via
///      [onUnauthorized] — the listener is responsible for clearing the
///      token and bouncing the user back to the auth flow.
///
/// One instance is registered as a singleton in `core/di/injection.dart`
/// and shared by every remote datasource.
class DioClient {
  DioClient(
    this._storage, {
    this.onUnauthorized,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // Only treat 401 as "token expired/invalid" when the request
          // actually carried an Authorization header. Login/register
          // legitimately receive 401 on bad credentials and must NOT
          // trigger a global logout.
          final status = error.response?.statusCode;
          final wasAuthenticated =
              error.requestOptions.headers['Authorization'] != null;

          if (status == 401 && wasAuthenticated) {
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  final SecureStorageService _storage;

  /// Invoked once per failed authenticated request that came back 401.
  /// Wired in `injection.dart` to dispatch [LogoutRequested] on [AuthBloc],
  /// which clears the stored JWT and lets the router redirect to /welcome.
  final void Function()? onUnauthorized;

  late final Dio _dio;

  Dio get dio => _dio;
}
