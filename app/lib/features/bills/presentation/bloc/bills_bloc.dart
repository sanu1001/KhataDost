import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/bill.dart';
import '../../domain/repositories/billing_repository.dart';

part 'bills_event.dart';
part 'bills_state.dart';

/// The bills HISTORY list (`GET /v1/bills`) — separate concern from the
/// draft ([BillBuilderBloc]): one answers "what did I sell?", the other
/// holds the notebook currently being written.
class BillsBloc extends Bloc<BillsEvent, BillsState> {
  BillsBloc(this._repository) : super(BillsState.initial()) {
    on<BillsLoadRequested>(_onLoadRequested);
  }

  final BillingRepository _repository;

  Future<void> _onLoadRequested(
      BillsLoadRequested event, Emitter<BillsState> emit) async {
    emit(state.copyWith(status: BillsStatus.loading, clearError: true));
    try {
      final bills = await _repository.getBills();
      emit(state.copyWith(
        status: BillsStatus.loaded,
        bills: bills,
        clearError: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: BillsStatus.error,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: BillsStatus.error,
        errorMessage: 'Could not load bills',
      ));
    }
  }
}
