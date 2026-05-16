// app/lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart

import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../models/dashboard_summary_model.dart';
import 'dashboard_datasource.dart';

/// Real HTTP datasource for the dashboard summary endpoint.
/// Drop-in replacement for [DashboardMockDatasource] — same method signature,
/// same return type (the model extends the entity, so callers stay agnostic).
///
/// JWT is attached upstream by [DioClient]'s request interceptor.
class DashboardRemoteDataSource implements DashboardDataSource {
  const DashboardRemoteDataSource(this._client);

  final DioClient _client;

  @override
  Future<DashboardSummary> getSummary() async {
    try {
      final res = await _client.dio.get('/v1/dashboard/summary');
      return DashboardSummaryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(mapDioError(e), statusCode: e.response?.statusCode);
    }
  }
}
