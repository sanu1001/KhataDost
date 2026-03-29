import 'package:equatable/equatable.dart';

/// Events are just definitions — no logic, no state.
/// The BLoC handles what actually happens when each event fires.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once at app launch from SplashPage.
/// Triggers the saved-token check.
final class AppStarted extends AuthEvent {
  const AppStarted();
}

/// Fired when the user taps "Log in" and the form is valid.
final class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Fired when the user taps "Create account" and the form is valid.
final class RegisterRequested extends AuthEvent {
  const RegisterRequested({
    required this.name,
    required this.shopName,
    required this.phone,
    required this.email,
    required this.password,
    required this.accessCode,
  });
  final String name;
  final String shopName;
  final String phone;
  final String email;
  final String password;
  final String accessCode;

  @override
  List<Object?> get props =>
      [name, shopName, phone, email, password, accessCode];
}

/// Fired from Settings when the user taps "Logout".
final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}