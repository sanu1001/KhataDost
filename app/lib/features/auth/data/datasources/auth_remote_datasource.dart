import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_response_model.dart';
import 'auth_datasource.dart';
import 'auth_exception.dart';

/// Real HTTP datasource — wired in Step 4 of the build order.
/// Drop-in replacement for [AuthMockDatasource]; same method signatures.
class AuthRemoteDataSource implements AuthDataSource {
  const AuthRemoteDataSource(this._client);

  final DioClient _client;

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String shopName,
    required String phone,
    required String email,
    required String password,
    required String accessCode,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/register',
        data: {
          'name': name,
          'shop_name': shopName,
          'phone': phone,
          'email': email,
          'password': password,
          'access_code': accessCode,
        },
      );
      return AuthResponseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  String _extractMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['message'] as String? ?? _fallback(e);
      return _fallback(e);
    } catch (_) {
      return _fallback(e);
    }
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
}