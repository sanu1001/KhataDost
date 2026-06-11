part of 'khata_bloc.dart';

abstract class KhataEvent extends Equatable {
  const KhataEvent();

  @override
  List<Object?> get props => [];
}

/// Load (or reload) one customer's ledger. The singleton bloc serves one
/// customer at a time — a different [customerId] resets the state first.
class KhataLoadRequested extends KhataEvent {
  const KhataLoadRequested(this.customerId);

  final String customerId;

  @override
  List<Object?> get props => [customerId];
}

/// Record Payment submitted from the sheet. [amount] is null when the
/// text field didn't parse — the preflight turns that into the same
/// inline error as the server would.
class KhataPaymentSubmitted extends KhataEvent {
  const KhataPaymentSubmitted(this.amount);

  final double? amount;

  @override
  List<Object?> get props => [amount];
}

/// Clears stale payment status/error when the sheet (re)opens.
class KhataPaymentReset extends KhataEvent {
  const KhataPaymentReset();
}

/// A tapped credit entry wants its bill's items (the bottom sheet).
class KhataBillRequested extends KhataEvent {
  const KhataBillRequested(this.billId);

  final String billId;

  @override
  List<Object?> get props => [billId];
}
