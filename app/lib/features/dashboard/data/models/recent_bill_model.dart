// app/lib/features/dashboard/data/models/recent_bill_model.dart

import '../../domain/entities/dashboard_summary.dart';

/// Data-layer model for a single bill row in the dashboard summary response.
/// Extends the domain entity (mirrors [UserModel] → [User]) so the datasource
/// can return [DashboardSummary] / [RecentBill] directly without an extra
/// model → entity mapping pass.
class RecentBillModel extends RecentBill {
  const RecentBillModel({
    required super.id,
    required super.customerName,
    required super.amount,
    required super.createdAt,
  });

  /// Parses one element of the `recent_bills` array.
  /// snake_case (`customer_name`, `created_at`) → camelCase fields.
  /// `created_at` is RFC 3339 / ISO 8601 (e.g. `2026-05-15T10:00:00Z`).
  /// `amount` is read via [num] so the server may send either int or double.
  factory RecentBillModel.fromJson(Map<String, dynamic> json) => RecentBillModel(
        id: json['id'] as String,
        customerName: json['customer_name'] as String,
        amount: (json['amount'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
