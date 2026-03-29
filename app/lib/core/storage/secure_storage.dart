import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

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
}