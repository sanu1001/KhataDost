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
        // Token exists → user is considered authenticated for now.
        // Phase 4: call a /me endpoint here and populate the User object.
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearError: true));
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