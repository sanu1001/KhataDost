import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/secure_storage.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthDataSource datasource,
    required SecureStorageService storage,   // ← correct class name
  })  : _datasource = datasource,
        _storage = storage;

  final AuthDataSource _datasource;
  final SecureStorageService _storage;       // ← correct class name

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _datasource.login(email: email, password: password);
    await _storage.saveToken(response.token);
    return response.user;
  }

  @override
  Future<User> register({
    required String name,
    required String shopName,
    required String phone,
    required String email,
    required String password,
    required String accessCode,
  }) async {
    final response = await _datasource.register(
      name: name,
      shopName: shopName,
      phone: phone,
      email: email,
      password: password,
      accessCode: accessCode,
    );
    await _storage.saveToken(response.token);
    return response.user;
  }

  @override
  Future<void> logout() => _storage.clearToken();         // ← clearToken not deleteToken

  @override
  Future<String?> getSavedToken() => _storage.getToken(); // ← getToken not readToken
}