import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/repositories/billing_repository.dart';
import '../../domain/entities/khata_entry.dart';
import '../../domain/khata_math.dart' as km;
import '../../domain/repositories/khata_repository.dart';

part 'khata_event.dart';
part 'khata_state.dart';

/// One customer's dues ledger: timeline + server-derived balance +
/// Record Payment (the ONLY balance-down action, §12) + the tapped
/// credit entry's bill for the items sheet.
///
/// ONE GetIt singleton provided per-route in the customers branch —
/// state carries [KhataState.customerId]; navigating to a different
/// customer's khata resets it on load.
///
/// [BillingRepository] is READ-ONLY reuse of billing's existing contract
/// (`getBillById`) — exactly how the backend khata service reuses the
/// frozen customer repository. Billing pages and blocs are untouched.
class KhataBloc extends Bloc<KhataEvent, KhataState> {
  KhataBloc({
    required KhataRepository khataRepository,
    required BillingRepository billingRepository,
  })  : _khataRepository = khataRepository,
        _billingRepository = billingRepository,
        super(KhataState.initial()) {
    on<KhataLoadRequested>(_onLoadRequested);
    on<KhataPaymentSubmitted>(_onPaymentSubmitted);
    on<KhataPaymentReset>(_onPaymentReset);
    on<KhataBillRequested>(_onBillRequested);
  }

  final KhataRepository _khataRepository;
  final BillingRepository _billingRepository;

  Future<void> _onLoadRequested(
      KhataLoadRequested event, Emitter<KhataState> emit) async {
    // A different customer's ledger → full reset (the singleton must not
    // flash customer A's entries on customer B's page).
    if (state.customerId != event.customerId) {
      emit(KhataState.initial().copyWith(
        customerId: event.customerId,
        status: KhataStatus.loading,
      ));
    } else {
      emit(state.copyWith(status: KhataStatus.loading, clearError: true));
    }

    try {
      final khata = await _khataRepository.getKhata(event.customerId);
      emit(state.copyWith(
        status: KhataStatus.loaded,
        entries: khata.entries,
        balance: khata.balance,
        runningBalances: km.runningBalances(khata.entries),
        clearError: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: KhataStatus.error, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: KhataStatus.error,
        errorMessage: 'Could not load khata',
      ));
    }
  }

  Future<void> _onPaymentSubmitted(
      KhataPaymentSubmitted event, Emitter<KhataState> emit) async {
    final customerId = state.customerId;
    if (customerId == null) return;

    // Client preflight — same rule, same message as the server's 400.
    // The server stays the authority (the real check runs there too).
    final preflightError = km.paymentValidationError(event.amount);
    if (preflightError != null) {
      emit(state.copyWith(
        paymentStatus: KhataPaymentStatus.error,
        paymentError: preflightError,
      ));
      return;
    }

    emit(state.copyWith(
      paymentStatus: KhataPaymentStatus.submitting,
      clearPaymentError: true,
    ));

    try {
      await _khataRepository.recordPayment(
        customerId: customerId,
        amount: event.amount!,
      );

      // Re-fetch after write: balance is DERIVED — never patched
      // client-side. Fresh ledger + success land in ONE consistent emit.
      final khata = await _khataRepository.getKhata(customerId);
      emit(state.copyWith(
        status: KhataStatus.loaded,
        entries: khata.entries,
        balance: khata.balance,
        runningBalances: km.runningBalances(khata.entries),
        paymentStatus: KhataPaymentStatus.success,
        clearPaymentError: true,
        clearError: true,
      ));
    } on ApiException catch (e) {
      // 400 non-positive / 404 — the server's message, inline in the
      // sheet (settle-page precedent).
      emit(state.copyWith(
        paymentStatus: KhataPaymentStatus.error,
        paymentError: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        paymentStatus: KhataPaymentStatus.error,
        paymentError: 'Could not record payment',
      ));
    }
  }

  void _onPaymentReset(KhataPaymentReset event, Emitter<KhataState> emit) {
    emit(state.copyWith(
      paymentStatus: KhataPaymentStatus.idle,
      clearPaymentError: true,
    ));
  }

  Future<void> _onBillRequested(
      KhataBillRequested event, Emitter<KhataState> emit) async {
    emit(state.copyWith(
      billStatus: KhataBillStatus.loading,
      clearBill: true,
      clearBillError: true,
    ));

    try {
      final bill = await _billingRepository.getBillById(event.billId);
      emit(state.copyWith(billStatus: KhataBillStatus.loaded, bill: bill));
    } on ApiException catch (e) {
      emit(state.copyWith(
        billStatus: KhataBillStatus.error,
        billError: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        billStatus: KhataBillStatus.error,
        billError: 'Could not load the bill',
      ));
    }
  }
}
