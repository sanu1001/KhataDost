import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/shop_profile.dart';
import '../models/shop_profile_model.dart';
import 'settings_datasource.dart';

/// Real HTTP datasource for the profile endpoint (GET /v1/me).
/// Drop-in replacement for [SettingsMockDatasource] — same signature,
/// same return type. JWT is attached upstream by [DioClient]'s interceptor.
class SettingsRemoteDataSource implements SettingsDataSource {
  const SettingsRemoteDataSource(this._client);

  final DioClient _client;

  @override
  Future<ShopProfile> getProfile() async {
    try {
      final res = await _client.dio.get('/v1/me');
      return ShopProfileModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }
}
