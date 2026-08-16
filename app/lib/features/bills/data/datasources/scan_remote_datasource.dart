import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/scan_result.dart';
import '../models/scan_result_model.dart';
import 'scan_datasource.dart';

/// Real HTTP datasource for `POST /v1/scan`.
/// Drop-in replacement for [ScanMockDatasource] — same interface.
class ScanRemoteDatasource implements ScanDatasource {
  const ScanRemoteDatasource(this._client);

  final DioClient _client;

  @override
  Future<ScanResult> scan({
    required String imageBase64,
    required String mimeType,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/scan',
        data: {'image_base64': imageBase64, 'mime_type': mimeType},
        // The server holds the Gemini call up to 30 s before answering 504.
        // DioClient's default receiveTimeout is 15 s — give THIS request
        // room to receive the server's verdict instead of dying first.
        options: Options(receiveTimeout: const Duration(seconds: 35)),
      );
      return ScanResultModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 429 "scan limit reached…" / 504 "…timed out" are the graceful-
      // degradation cases (§4) — keep the server's friendly wording for
      // the toast; the shopkeeper falls back to manual add.
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
