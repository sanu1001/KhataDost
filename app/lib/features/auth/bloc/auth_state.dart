import 'package:equatable/equatable.dart';
import '../domain/entities/user.dart';

// What "phase" the auth flow is in right now.
enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

/// Single state class — no sealed variants.
/// Every variable the BLoC / UI needs lives here.
/// The BLoC emits copies via copyWith() to update individual fields.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;

  /// Non-null when status == authenticated.
  final User? user;

  /// Non-null when status == failure.
  final String? errorMessage;

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.failure;

  // ── Immutable update ──────────────────────────────────────────────────────

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    // Pass null explicitly to clear the error / user.
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}