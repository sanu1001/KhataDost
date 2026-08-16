import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/khata_entry.dart';
import '../models/khata_model.dart';
import 'khata_datasource.dart';

/// Real HTTP datasource for the khata endpoints.
/// Drop-in replacement for [KhataMockDatasource] — same interface.
/// JWT attached upstream by [DioClient]'s interceptor.
class KhataRemoteDatasource implements KhataDatasource {
  const KhataRemoteDatasource(this._client);

  final DioClient _client;

  @override
  Future<Khata> getKhata(String customerId) async {
    try {
      final res = await _client.dio.get('/v1/khata/$customerId');
      return KhataModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 404 (foreign/unknown customer) carries a meaningful message.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<KhataEntry> recordPayment({
    required String customerId,
    required double amount,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/khata/$customerId/payment',
        data: <String, dynamic>{'amount': amount},
      );
      return KhataEntryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // The 400 (non-positive amount) message surfaces INLINE in the
      // Record Payment sheet — same _serverMessageOr pattern as billing.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }
}

/// Extracts the `error` field from the server's JSON body if present.
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
