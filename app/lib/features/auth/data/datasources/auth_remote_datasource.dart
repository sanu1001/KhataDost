// app/lib/features/auth/data/datasources/auth_remote_datasource.dart

import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../models/auth_response_model.dart';
import 'auth_datasource.dart';

/// Real HTTP datasource for the auth endpoints.
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
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
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
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }
}
