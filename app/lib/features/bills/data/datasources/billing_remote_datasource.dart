import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/draft_line.dart';
import '../models/bill_model.dart';
import 'billing_datasource.dart';

/// Real HTTP datasource for the bills endpoints.
/// Drop-in replacement for [BillingMockDatasource] — same interface.
/// JWT attached upstream by [DioClient]'s interceptor.
class BillingRemoteDatasource implements BillingDatasource {
  const BillingRemoteDatasource(this._client);

  final DioClient _client;

  @override
  Future<Bill> createBill({
    required String? customerId,
    required double amountPaid,
    required List<DraftLine> lines,
  }) async {
    try {
      // Datasource owns the request shape: draft lines resolve to the
      // POST /v1/bills line contract. The server recomputes all money.
      final body = <String, dynamic>{
        'customer_id': customerId, // null = walk-in
        'amount_paid': amountPaid, // always explicit ("paying now")
        'items': [
          for (final l in lines)
            {
              'item_id': l.itemId,
              'variant_id': l.variantId,
              'name': l.name,
              'quantity': l.quantity,
              'unit_price': l.unitPrice,
            },
        ],
      };

      final res = await _client.dio.post('/v1/bills', data: body);
      return BillModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 409 walk-in / 400 validation carry meaningful server messages —
      // surface them so the settle screen can show them inline.
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<Bill>> getBills() async {
    try {
      final res = await _client.dio.get('/v1/bills');
      final list = res.data['bills'] as List<dynamic>;
      return list
          .map((e) => BillModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<Bill> getBillById(String id) async {
    try {
      final res = await _client.dio.get('/v1/bills/$id');
      return BillModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
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
