part of 'bills_bloc.dart';

enum BillsStatus { initial, loading, loaded, error }

class BillsState extends Equatable {
  const BillsState({
    required this.status,
    required this.bills,
    required this.errorMessage,
  });

  factory BillsState.initial() => const BillsState(
        status: BillsStatus.initial,
        bills: [],
        errorMessage: null,
      );

  final BillsStatus status;

  /// Headers only (items empty), newest first — the GET /v1/bills shape.
  final List<Bill> bills;
  final String? errorMessage;

  bool get isLoading => status == BillsStatus.loading;

  BillsState copyWith({
    BillsStatus? status,
    List<Bill>? bills,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BillsState(
      status: status ?? this.status,
      bills: bills ?? this.bills,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, bills, errorMessage];
}
