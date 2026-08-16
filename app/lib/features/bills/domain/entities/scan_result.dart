import 'package:equatable/equatable.dart';

import '../../../inventory/domain/entities/item.dart';

/// `POST /v1/scan` result — a SUGGESTION, never a record (scan persists
/// nothing; the bill only exists once settled via `POST /v1/bills`).
class ScanResult extends Equatable {
  const ScanResult({required this.matches, required this.unmatched});

  final List<ScanMatch> matches;
  final List<UnmatchedDetection> unmatched;

  /// Empty photo / nothing above the confidence gate → both empty.
  /// Not an error — the manual on-ramp is always there.
  bool get isEmpty => matches.isEmpty && unmatched.isEmpty;

  @override
  List<Object?> get props => [matches, unmatched];
}

/// A detection matched to one of THIS user's inventory cards. The AI is a
/// card-picker, not a price-picker (§10): [item] arrives at its
/// [defaultVariantId]; variant/price stays with the shopkeeper (swipe).
class ScanMatch extends Equatable {
  const ScanMatch({
    required this.detectedLabel,
    required this.detectedQuantity,
    required this.defaultVariantId,
    required this.item,
  });

  final String detectedLabel;
  final int detectedQuantity; // pre-fills the line's count
  final String defaultVariantId;

  /// The EXISTING inventory entity — scan matches are always Type A
  /// ([UnitItem]); the response mirrors the inventory card JSON exactly.
  final Item item;

  @override
  List<Object?> get props =>
      [detectedLabel, detectedQuantity, defaultVariantId, item];
}

/// A detection with no inventory match — becomes a pre-filled misc line
/// (name + qty in, price typed by the shopkeeper).
class UnmatchedDetection extends Equatable {
  const UnmatchedDetection({required this.label, required this.quantity});

  final String label;
  final int quantity;

  @override
  List<Object?> get props => [label, quantity];
}
