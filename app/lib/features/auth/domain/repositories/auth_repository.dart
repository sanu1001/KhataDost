import '../entities/user.dart';

/// Contract every auth repository must satisfy.
/// The BLoC only ever talks to this — never to Dio, storage, or any package.
abstract class AuthRepository {
  /// Authenticates the user. Saves the token internally.
  /// Returns the [User] on success. Throws [AuthException] on failure.
  Future<User> login({
    required String email,
    required String password,
  });

  /// Registers a new user. Saves the token internally.
  /// Returns the [User] on success. Throws [AuthException] on failure.
  Future<User> register({
    required String name,
    required String shopName,
    required String phone,
    required String email,
    required String password,
    required String accessCode,
  });

  /// Clears the stored JWT.
  Future<void> logout();

  /// Returns the stored JWT string, or null if none exists.
  Future<String?> getSavedToken();
}