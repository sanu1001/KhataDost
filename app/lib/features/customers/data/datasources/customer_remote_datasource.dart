import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../models/customer_model.dart';
import 'customer_datasource.dart';

/// Real HTTP datasource for the customers endpoints.
/// Drop-in replacement for [CustomerMockDatasource] — same interface,
/// same return types. JWT attached upstream by [DioClient]'s interceptor.
class CustomerRemoteDataSource implements CustomerDatasource {
  const CustomerRemoteDataSource(this._client);

  final DioClient _client;

  @override
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final res = await _client.dio.get('/v1/customers');
      final list = res.data['customers'] as List<dynamic>;
      return list
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<CustomerModel> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/customers',
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'notes': notes,
        },
      );
      return CustomerModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 400 = duplicate phone — surface the server's message directly.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<CustomerModel> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    try {
      final res = await _client.dio.put(
        '/v1/customers/$id',
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'notes': notes,
        },
      );
      return CustomerModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 400 = dup phone, 404 = not found — surface server message.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await _client.dio.delete('/v1/customers/$id');
    } on DioException catch (e) {
      // 409 = has dues — surface server message so BLoC shows it inline.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }
}

/// Extracts the `error` field from the server's JSON body if present,
/// falling back to [fallback] if the body is missing or malformed.
///
/// Server error shape: { "error": "some message" }
String _serverMessageOr(DioException e, String fallback) {
  try {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
  } catch (_) {}
  return fallback;
}