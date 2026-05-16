import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_datasource.dart';

/// Concrete repository. Today it just delegates to the datasource.
/// When models/JSON are added in Phase 8, this is where DTO → entity
/// mapping (and any cross-source orchestration) will live.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required DashboardDataSource datasource})
      : _datasource = datasource;

  final DashboardDataSource _datasource;

  @override
  Future<DashboardSummary> getSummary() => _datasource.getSummary();
}
