import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// Key for the persisted user-profile snapshot (saved at login/register,
  /// read on cold start to hydrate AuthState.user).
  /// Lives here instead of AppConstants because app_constants.dart is
  /// skip-worktree'd (baseUrl LAN-IP guard) — an addition there could never
  /// be committed.
  static const _userJsonKey = 'auth_user_json';

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  Future<void> saveToken(String token) => _storage.write(
    key: AppConstants.jwtKey,
    value: token,
    aOptions: _androidOptions,
  );

  Future<String?> getToken() => _storage.read(
    key: AppConstants.jwtKey,
    aOptions: _androidOptions,
  );

  Future<void> clearToken() => _storage.delete(
    key: AppConstants.jwtKey,
    aOptions: _androidOptions,
  );

  // ── User-profile snapshot (raw JSON string) ───────────────────────────────

  Future<void> saveUser(String userJson) => _storage.write(
    key: _userJsonKey,
    value: userJson,
    aOptions: _androidOptions,
  );

  Future<String?> getUser() => _storage.read(
    key: _userJsonKey,
    aOptions: _androidOptions,
  );

  Future<void> clearUser() => _storage.delete(
    key: _userJsonKey,
    aOptions: _androidOptions,
  );
}
