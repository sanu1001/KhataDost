import '../entities/dashboard_summary.dart';

/// Contract every dashboard repository must satisfy.
/// The BLoC only ever talks to this — never to Dio, storage, or any package.
abstract class DashboardRepository {
  /// Fetches today's sales total and the 3 most recent bills.
  /// Throws an exception on failure; the BLoC catches and surfaces the message.
  Future<DashboardSummary> getSummary();
}
