import '../../domain/entities/dashboard_summary.dart';

/// Datasource contract. Implementations: mock (in-memory) and remote (Dio).
/// Swapping mock → remote is one line change in `core/di/injection.dart`.
abstract class DashboardDataSource {
  Future<DashboardSummary> getSummary();
}
