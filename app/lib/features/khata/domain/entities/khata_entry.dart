import 'package:equatable/equatable.dart';

/// The two ledger entry kinds (§11). Credit = a bill on tab (pushes the
/// balance up, links its bill). Payment = money received (pushes it down,
/// never has items or a bill).
enum KhataEntryType { credit, payment }

/// One append-only ledger entry — the server's khataEntryResponse shape.
/// Amounts are positive in both kinds; the SIGN lives in the type
/// (see `khata_math.signedAmount`).
class KhataEntry extends Equatable {
  const KhataEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.billId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final KhataEntryType type;
  final double amount;

  /// Set on credit entries (tapping shows that bill's items). null on
  /// payments — and on credit entries whose bill was deleted
  /// (`ON DELETE SET NULL`), which render as plain, non-tappable rows.
  final String? billId;

  /// Unused for now (server always sends null) — schema-ready for a
  /// future "add note" field.
  final String? note;
  final DateTime createdAt;

  bool get isCredit => type == KhataEntryType.credit;
  bool get isPayment => type == KhataEntryType.payment;

  /// Tappable in the timeline: only a credit entry with a live bill link.
  bool get hasBill => isCredit && billId != null;

  @override
  List<Object?> get props => [id, type, amount, billId, note, createdAt];
}

/// The `GET /v1/khata/{customerId}` view: SERVER-derived balance
/// (Σcredit − Σpayment — never stored, never typed, §12) + the full entry
/// timeline, oldest first (server order).
class Khata extends Equatable {
  const Khata({required this.balance, required this.entries});

  final double balance;

  /// Oldest first. NOTE: when parsed by [KhataModel] this is a runtime
  /// `List<KhataEntryModel>` — lookups must stay loop-based (covariance;
  /// see bill_math_test's regression group and the one in
  /// khata_math_test).
  final List<KhataEntry> entries;

  @override
  List<Object?> get props => [balance, entries];
}
