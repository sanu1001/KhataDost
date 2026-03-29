/// Single exception type thrown by all auth datasources (mock + remote).
/// The repository catches this and surfaces [message] to the BLoC → UI.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}