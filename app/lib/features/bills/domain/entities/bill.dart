import 'package:equatable/equatable.dart';

/// A PERSISTED bill — the resolved snapshot the server stored (header +
/// optionally its lines). Money fields are server-computed; the client
/// never derives them for display of saved bills.
class Bill extends Equatable {
  const Bill({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.amountPaid,
    required this.createdAt,
    required this.items,
  });

  final String id;

  /// null = walk-in (nullable-by-design, not a missing value).
  final String? customerId;

  /// Denormalized snapshot ("Walk-in" or the customer's name at sale time).
  final String customerName;

  /// Bill TOTAL (server-computed; dashboard sums this column).
  final double amount;
  final double amountPaid;
  final DateTime createdAt;

  /// Empty in list responses (`GET /v1/bills`); populated on detail/create.
  final List<BillItem> items;

  /// Settlement flavor, derived for display badges.
  bool get isWalkIn => customerId == null;
  bool get isFullyPaid => amountPaid >= amount;
  double get creditAmount => amount - amountPaid;

  @override
  List<Object?> get props =>
      [id, customerId, customerName, amount, amountPaid, createdAt, items];
}

/// A persisted bill line — resolved result, denormalized (delete-safe).
class BillItem extends Equatable {
  const BillItem({
    required this.id,
    required this.itemId,
    required this.variantId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String id;
  final String? itemId; // null = miscellaneous
  final String? variantId; // null = Type B or miscellaneous
  final String name;
  final double quantity; // count (2.000) or measure (0.750)
  final double unitPrice;
  final double lineTotal; // server-computed

  @override
  List<Object?> get props =>
      [id, itemId, variantId, name, quantity, unitPrice, lineTotal];
}
