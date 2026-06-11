part of 'bill_builder_bloc.dart';

/// Events are pure triggers — no logic (convention). Cell-edit events are
/// addressed by the line's LOCAL draft id.
abstract class BillBuilderEvent extends Equatable {
  const BillBuilderEvent();

  @override
  List<Object?> get props => [];
}

/// Start a fresh draft (after a successful settle, or explicit discard).
class BillBuilderReset extends BillBuilderEvent {
  const BillBuilderReset();
}

/// On-ramp 1: a captured photo (camera or gallery). The bloc encodes and
/// posts it; matches/unmatched merge into the CURRENT draft (scan-more
/// just fires this again).
class ScanRequested extends BillBuilderEvent {
  const ScanRequested(this.imageBytes);

  final Uint8List imageBytes;

  @override
  List<Object?> get props => [imageBytes];
}

/// On-ramp 2: an inventory item tapped in the add-item sheet.
/// Unit → line at default variant, count 1. Loose → line at measure 0.
class ItemPicked extends BillBuilderEvent {
  const ItemPicked(this.item);

  final Item item;

  @override
  List<Object?> get props => [item];
}

/// The escape hatch: a blank miscellaneous row (name '', qty 1, price 0).
class MiscLineAdded extends BillBuilderEvent {
  const MiscLineAdded();
}

class LineRemoved extends BillBuilderEvent {
  const LineRemoved(this.lineId);

  final String lineId;

  @override
  List<Object?> get props => [lineId];
}

/// Swipe = variant = price (§10). Only meaningful on unit lines.
class VariantSwiped extends BillBuilderEvent {
  const VariantSwiped(this.lineId, this.variantId);

  final String lineId;
  final String variantId;

  @override
  List<Object?> get props => [lineId, variantId];
}

/// Count for unit/misc lines, measure for loose lines (live recompute).
class LineQuantityChanged extends BillBuilderEvent {
  const LineQuantityChanged(this.lineId, this.quantity);

  final String lineId;
  final double quantity;

  @override
  List<Object?> get props => [lineId, quantity];
}

/// Hand-typed price cell — sets the override (wins until the next swipe).
class LinePriceChanged extends BillBuilderEvent {
  const LinePriceChanged(this.lineId, this.price);

  final String lineId;
  final double price;

  @override
  List<Object?> get props => [lineId, price];
}

class LineNameChanged extends BillBuilderEvent {
  const LineNameChanged(this.lineId, this.name);

  final String lineId;
  final String name;

  @override
  List<Object?> get props => [lineId, name];
}

/// null/null = walk-in (the default).
class SettleCustomerChanged extends BillBuilderEvent {
  const SettleCustomerChanged({this.customerId, this.customerName});

  final String? customerId;
  final String? customerName;

  @override
  List<Object?> get props => [customerId, customerName];
}

/// null = field cleared → fall back to the default (= bill total).
class PayingNowChanged extends BillBuilderEvent {
  const PayingNowChanged(this.amount);

  final double? amount;

  @override
  List<Object?> get props => [amount];
}

class BillSubmitted extends BillBuilderEvent {
  const BillSubmitted();
}
