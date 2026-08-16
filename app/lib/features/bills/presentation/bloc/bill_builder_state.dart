part of 'bill_builder_bloc.dart';

enum BillBuilderStatus { editing, submitting, success, failure }

/// Scan is a sub-state of the SAME draft (one source of truth): a failed
/// scan never touches the lines — the manual on-ramp is unaffected.
enum ScanStatus { idle, scanning, failure }

class BillBuilderState extends Equatable {
  const BillBuilderState({
    required this.status,
    required this.scanStatus,
    required this.lines,
    required this.total,
    required this.customerId,
    required this.customerName,
    required this.payingNow,
    required this.errorMessage,
    required this.scanMessage,
    required this.lastCreatedBill,
  });

  factory BillBuilderState.initial() => const BillBuilderState(
        status: BillBuilderStatus.editing,
        scanStatus: ScanStatus.idle,
        lines: [],
        total: 0,
        customerId: null,
        customerName: null,
        payingNow: null,
        errorMessage: null,
        scanMessage: null,
        lastCreatedBill: null,
      );

  final BillBuilderStatus status;
  final ScanStatus scanStatus;

  /// The notebook — ordered, every cell editable.
  final List<DraftLine> lines;

  /// Running total — DERIVED from [lines], recomputed in the same emit
  /// (advisory display; the server recomputes at settle).
  final double total;

  /// Settle inputs (§12). null customer = walk-in.
  final String? customerId;
  final String? customerName;

  /// "Paying now" as typed; null = untouched → defaults to [total].
  final double? payingNow;

  /// Submit errors, shown INLINE on the settle screen (the walk-in 409
  /// arrives here with the server's exact message).
  final String? errorMessage;

  /// Scan failure text for the toast (server's friendly 429/504 wording).
  final String? scanMessage;

  final Bill? lastCreatedBill;

  // ── Derived helpers ───────────────────────────────────────────────────

  double get effectivePayingNow => payingNow ?? payingNowDefault(total);
  bool get isWalkIn => customerId == null;
  bool get isEmpty => lines.isEmpty;
  bool get isSubmitting => status == BillBuilderStatus.submitting;
  bool get isScanning => scanStatus == ScanStatus.scanning;

  /// What the shortfall/surplus will do, for the settle screen's hint.
  double get creditDelta => total - effectivePayingNow;

  BillBuilderState copyWith({
    BillBuilderStatus? status,
    ScanStatus? scanStatus,
    List<DraftLine>? lines,
    double? total,
    String? customerId,
    String? customerName,
    double? payingNow,
    String? errorMessage,
    String? scanMessage,
    Bill? lastCreatedBill,
    bool clearError = false,
    bool clearScanMessage = false,
    bool clearCustomer = false,
    bool clearPayingNow = false,
    bool clearLastCreatedBill = false,
  }) {
    return BillBuilderState(
      status: status ?? this.status,
      scanStatus: scanStatus ?? this.scanStatus,
      lines: lines ?? this.lines,
      total: total ?? this.total,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName:
          clearCustomer ? null : (customerName ?? this.customerName),
      payingNow: clearPayingNow ? null : (payingNow ?? this.payingNow),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      scanMessage:
          clearScanMessage ? null : (scanMessage ?? this.scanMessage),
      lastCreatedBill: clearLastCreatedBill
          ? null
          : (lastCreatedBill ?? this.lastCreatedBill),
    );
  }

  @override
  List<Object?> get props => [
        status,
        scanStatus,
        lines,
        total,
        customerId,
        customerName,
        payingNow,
        errorMessage,
        scanMessage,
        lastCreatedBill,
      ];
}
