import '../entities/user.dart';

/// Contract every auth repository must satisfy.
/// The BLoC only ever talks to this — never to Dio, storage, or any package.
abstract class AuthRepository {
  /// Authenticates the user. Saves the token internally.
  /// Returns the [User] on success. Throws [ApiException] on failure.
  Future<User> login({
    required String email,
    required String password,
  });

  /// Registers a new user. Saves the token internally.
  /// Returns the [User] on success. Throws [ApiException] on failure.
  Future<User> register({
    required String name,
    required String shopName,
    required String phone,
    required String email,
    required String password,
    required String accessCode,
  });

  /// Clears the stored JWT (and the persisted user snapshot).
  Future<void> logout();

  /// Returns the stored JWT string, or null if none exists.
  Future<String?> getSavedToken();

  /// Returns the user snapshot persisted at the last login/register,
  /// or null if none exists (or it can't be parsed). Never throws —
  /// a corrupt snapshot must not break cold start.
  Future<User?> getSavedUser();
}
