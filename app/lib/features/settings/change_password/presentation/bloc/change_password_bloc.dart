import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/change_password_repository.dart';
import 'change_password_event.dart';
import 'change_password_state.dart';

/// PLACEHOLDER bloc. The flow is fully wired (submitting → success/failure),
/// but the datasource throws UnimplementedError until you build
/// PUT /v1/auth/password — so submit currently lands in `failure`.
/// Follow features/settings/presentation/bloc/settings_bloc.dart.
class ChangePasswordBloc
    extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  ChangePasswordBloc({required ChangePasswordRepository repository})
      : _repo = repository,
        super(const ChangePasswordState()) {
    on<SubmitRequested>(_onSubmitRequested);
  }

  final ChangePasswordRepository _repo;

  Future<void> _onSubmitRequested(
    SubmitRequested event,
    Emitter<ChangePasswordState> emit,
  ) async {
    emit(state.copyWith(
      status: ChangePasswordStatus.submitting,
      clearError: true,
    ));

    try {
      await _repo.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(state.copyWith(status: ChangePasswordStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: ChangePasswordStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
