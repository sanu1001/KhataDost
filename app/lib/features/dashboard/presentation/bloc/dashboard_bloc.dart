import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/dashboard_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

/// DashboardBloc owns ALL dashboard logic.
///
/// Pattern:
///   - Events  → just triggers (defined in dashboard_event.dart)
///   - State   → single class with status + summary + errorMessage fields
///   - BLoC    → listens to events, calls repository, emits state copies
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required DashboardRepository repository})
      : _repo = repository,
        super(const DashboardState()) {
    on<DashboardLoadRequested>(_onLoadRequested);
  }

  final DashboardRepository _repo;

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    // Keep previous summary in state so the UI can render last-known data
    // underneath the skeleton during refetch (instead of flashing empty).
    debugPrint('🔄 DashboardLoadRequested fired');  // add this
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));

    try {
      final summary = await _repo.getSummary();
      emit(state.copyWith(
        status: DashboardStatus.loaded,
        summary: summary,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
