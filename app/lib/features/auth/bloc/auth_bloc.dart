import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// AuthBloc owns ALL auth logic.
///
/// Pattern:
///   - Events  → just triggers (defined in auth_event.dart)
///   - State   → single class with status + user + errorMessage fields
///   - BLoC    → listens to events, calls repository, emits state copies
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repo = repository,
        super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _repo;

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onAppStarted(
      AppStarted event,
      Emitter<AuthState> emit,
      ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final token = await _repo.getSavedToken();

      if (token != null && token.isNotEmpty) {
        // Cold-start hydration: restore the user snapshot persisted at
        // login/register so state.user is populated BEFORE `authenticated`
        // is emitted (the dashboard greeting reads it via context.read in
        // build — it must be there on first build; a later re-emit would
        // not repaint it).
        //
        // No /v1/me call here on purpose: token validity is enforced by the
        // first protected request anyway (dead token → 401 → DioClient's
        // onUnauthorized → LogoutRequested), and blocking the splash on the
        // network would degrade offline/server-down cold starts. Settings
        // fetches /v1/me fresh whenever the profile is actually viewed.
        //
        // savedUser may be null on installs that logged in before user
        // persistence shipped — UI falls back gracefully; next login fixes it.
        final savedUser = await _repo.getSavedUser();
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: savedUser,
          clearError: true,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearError: true));
      }
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearError: true));
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));

    try {
      final user = await _repo.login(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRegisterRequested(
      RegisterRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));

    try {
      final user = await _repo.register(
        name: event.name,
        shopName: event.shopName,
        phone: event.phone,
        email: event.email,
        password: event.password,
        accessCode: event.accessCode,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event,
      Emitter<AuthState> emit,
      ) async {
    await _repo.logout();
    emit(state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearError: true,
    ));
  }
}
