import 'package:equatable/equatable.dart';

/// Aggregated dashboard payload returned by the summary endpoint.
/// Pure Dart — no JSON, no Dio, no dependencies outside Equatable.
class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.todaySales,
    required this.recentBills,
  });

  /// Sum of today's bills in INR, computed server-side in Asia/Kolkata.
  /// 0.0 means no bills today (silently — no special empty UI).
  final double todaySales;

  /// Up to 3 most recent bills, newest first.
  /// May be empty.
  final List<RecentBill> recentBills;

  @override
  List<Object?> get props => [todaySales, recentBills];
}

/// One row in the "Recent bills" list on the dashboard.
class RecentBill extends Equatable {
  const RecentBill({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.createdAt,
  });

  final String id;

  /// "Walk-in" when no linked customer.
  final String customerName;

  /// Bill total in INR.
  final double amount;

  /// Server timestamp (UTC). Format client-side as "2 hours ago".
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, customerName, amount, createdAt];
}
