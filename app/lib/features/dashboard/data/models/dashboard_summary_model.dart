// app/lib/features/dashboard/data/models/dashboard_summary_model.dart

import '../../domain/entities/dashboard_summary.dart';
import 'recent_bill_model.dart';

/// Data-layer model for `GET /v1/dashboard/summary`.
/// Extends the domain entity so the remote datasource can return it directly
/// as a [DashboardSummary] (same trick as [UserModel] → [User]).
class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.todaySales,
    required super.recentBills,
  });

  /// Parses the JSON envelope:
  ///   { "today_sales": <num>, "recent_bills": [ … ] }
  /// Defends against a missing/null `recent_bills` array by treating it as
  /// empty — the spec says "up to 3" so 0 is valid (silent empty state).
  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final billsJson = (json['recent_bills'] as List<dynamic>?) ?? const [];
    return DashboardSummaryModel(
      todaySales: (json['today_sales'] as num).toDouble(),
      recentBills: billsJson
          .map((e) => RecentBillModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
