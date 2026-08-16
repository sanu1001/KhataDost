part of 'khata_bloc.dart';

enum KhataStatus { initial, loading, loaded, error }

/// The Record Payment sheet's own lifecycle (status stays loaded behind
/// it) — same sub-status pattern as BillBuilder's scanStatus.
enum KhataPaymentStatus { idle, submitting, success, error }

/// The bill-items sheet's lifecycle (a tapped credit entry).
enum KhataBillStatus { idle, loading, loaded, error }

class KhataState extends Equatable {
  const KhataState({
    required this.customerId,
    required this.status,
    required this.entries,
    required this.balance,
    required this.runningBalances,
    required this.errorMessage,
    required this.paymentStatus,
    required this.paymentError,
    required this.billStatus,
    required this.bill,
    required this.billError,
  });

  factory KhataState.initial() => const KhataState(
        customerId: null,
        status: KhataStatus.initial,
        entries: [],
        balance: 0,
        runningBalances: [],
        errorMessage: null,
        paymentStatus: KhataPaymentStatus.idle,
        paymentError: null,
        billStatus: KhataBillStatus.idle,
        bill: null,
        billError: null,
      );

  /// Whose ledger is loaded (the singleton serves one customer at a time).
  final String? customerId;

  // ── Ledger load ────────────────────────────────────────────────────────
  final KhataStatus status;

  /// Oldest first (server order). Runtime `List<KhataEntryModel>` when
  /// real — lookups stay loop-based (covariance).
  final List<KhataEntry> entries;

  /// The SERVER's derived balance — the figure the header shows.
  final double balance;

  /// Bloc-derived (khata_math.runningBalances), aligned 1:1 with
  /// [entries] — recomputed on every load and emitted in the same state
  /// (customers' visibleCustomers precedent).
  final List<double> runningBalances;
  final String? errorMessage;

  // ── Record Payment sheet ───────────────────────────────────────────────
  final KhataPaymentStatus paymentStatus;

  /// Inline in the sheet — the preflight's or the server's message.
  final String? paymentError;

  // ── Bill-items sheet ───────────────────────────────────────────────────
  final KhataBillStatus billStatus;

  /// The tapped credit entry's bill (header + nested items).
  final Bill? bill;
  final String? billError;

  bool get isLoading => status == KhataStatus.loading;
  bool get isSubmittingPayment =>
      paymentStatus == KhataPaymentStatus.submitting;
  bool get hasEntries => entries.isNotEmpty;

  KhataState copyWith({
    String? customerId,
    KhataStatus? status,
    List<KhataEntry>? entries,
    double? balance,
    List<double>? runningBalances,
    String? errorMessage,
    bool clearError = false,
    KhataPaymentStatus? paymentStatus,
    String? paymentError,
    bool clearPaymentError = false,
    KhataBillStatus? billStatus,
    Bill? bill,
    bool clearBill = false,
    String? billError,
    bool clearBillError = false,
  }) {
    return KhataState(
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      entries: entries ?? this.entries,
      balance: balance ?? this.balance,
      runningBalances: runningBalances ?? this.runningBalances,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentError:
          clearPaymentError ? null : (paymentError ?? this.paymentError),
      billStatus: billStatus ?? this.billStatus,
      bill: clearBill ? null : (bill ?? this.bill),
      billError: clearBillError ? null : (billError ?? this.billError),
    );
  }

  @override
  List<Object?> get props => [
        customerId,
        status,
        entries,
        balance,
        runningBalances,
        errorMessage,
        paymentStatus,
        paymentError,
        billStatus,
        bill,
        billError,
      ];
}
