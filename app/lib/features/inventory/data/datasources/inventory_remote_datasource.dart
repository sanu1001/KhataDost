import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/item.dart';
import '../models/inventory_model.dart';
import 'inventory_datasource.dart';

/// Real HTTP datasource for the inventory endpoints.
/// Drop-in replacement for [InventoryMockDatasource] — same interface.
/// JWT attached upstream by [DioClient]'s interceptor.
class InventoryRemoteDataSource implements InventoryDatasource {
  const InventoryRemoteDataSource(this._client);

  final DioClient _client;

  @override
  Future<List<Item>> getItems() async {
    try {
      final res = await _client.dio.get('/v1/inventory');
      final list = res.data['items'] as List<dynamic>;
      return list
          .map((e) => itemFromJson(e as Map<String, dynamic>)) // polymorphic dispatch
          .toList();
    } on DioException catch (e) {
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<Item> createItem({
    required String name,
    required String pricingType,
    List<ItemVariant>? variants, // unit only
    double? rate,                // loose only
    String? unit,                // loose only
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'pricing_type': pricingType,
      };
      if (pricingType == 'unit') {
        // Option A: serialize variants inline (datasource owns the request shape).
        body['variants'] = (variants ?? [])
            .map((v) => {
          'label': v.label,
          'price': v.price,
          'is_default': v.isDefault,
        })
            .toList();
      } else {
        body['rate'] = rate;
        body['unit'] = unit;
      }

      final res = await _client.dio.post('/v1/inventory', data: body);
      return itemFromJson(res.data as Map<String, dynamic>); // nested item back
    } on DioException catch (e) {
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<Item> updateItem({
    required String id,
    required String name,
    double? rate,
    String? unit,
  }) async {
    try {
      final res = await _client.dio.put(
        '/v1/inventory/$id',
        data: {'name': name, 'rate': rate, 'unit': unit},
      );
      return itemFromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteItem({required String id}) async {
    try {
      await _client.dio.delete('/v1/inventory/$id');
    } on DioException catch (e) {
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<ItemVariant> addVariant({
    required String itemId,
    required String label,
    required double price,
    required bool isDefault,
  }) async {
    try {
      final res = await _client.dio.post(
        '/v1/inventory/$itemId/variants',
        data: {'label': label, 'price': price, 'is_default': isDefault},
      );
      return ItemVariantModel.fromJson(res.data as Map<String, dynamic>); // lone variant
    } on DioException catch (e) {
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<ItemVariant> updateVariant({
    required String itemId,
    required String variantId,
    String? label,
    double? price,
    bool? isDefault,
  }) async {
    try {
      final res = await _client.dio.put(
        '/v1/inventory/$itemId/variants/$variantId',
        data: {'label': label, 'price': price, 'is_default': isDefault},
      );
      return ItemVariantModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(
        _serverMessageOr(e, mapDioError(e)),
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteVariant({required String itemId, required String variantId}) async {
    try {
      await _client.dio.delete('/v1/inventory/$itemId/variants/$variantId');
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