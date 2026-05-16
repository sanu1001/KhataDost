import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_datasource.dart';

/// Hardcoded dashboard data for UI development.
/// Drop-in replacement for the real Dio datasource (Phase 8 of the build order).
class DashboardMockDatasource implements DashboardDataSource {
  @override
  Future<DashboardSummary> getSummary() async {
    // Simulate network latency so the skeleton actually shows.
    await Future.delayed(const Duration(milliseconds: 700));

    final now = DateTime.now();
    return DashboardSummary(
      todaySales: 3450.00,
      recentBills: [
        RecentBill(
          id: 'b1',
          customerName: 'Suresh Kumar',
          amount: 540.00,
          createdAt: now,
        ),
        RecentBill(
          id: 'b2',
          customerName: 'Walk-in',
          amount: 120.00,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        RecentBill(
          id: 'b3',
          customerName: 'Meena Devi',
          amount: 890.00,
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
      ],
    );
  }
}
