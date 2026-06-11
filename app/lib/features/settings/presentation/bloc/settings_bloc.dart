import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// SettingsBloc owns the profile-fetch logic for the Settings page.
///
/// Pattern (matches dashboard/auth):
///   - Events  → just triggers (settings_event.dart)
///   - State   → single class with status + profile + errorMessage
///   - BLoC    → listens, calls repository, emits state copies
///
/// Logout is NOT handled here — it is dispatched on the frozen AuthBloc as
/// LogoutRequested (read-only reuse).
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required SettingsRepository repository})
      : _repo = repository,
        super(const SettingsState()) {
    on<LoadProfile>(_onLoadProfile);
  }

  final SettingsRepository _repo;

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));

    try {
      final profile = await _repo.getProfile();
      emit(state.copyWith(status: SettingsStatus.loaded, profile: profile));
    } catch (e) {
      emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
