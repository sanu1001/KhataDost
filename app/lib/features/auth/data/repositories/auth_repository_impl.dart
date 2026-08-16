import 'dart:convert';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/secure_storage.dart';
import '../datasources/auth_datasource.dart';
import '../models/user_model.dart';

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
    // Persist the profile snapshot so cold start can rehydrate
    // AuthState.user without a network call (see AuthBloc._onAppStarted).
    await _storage.saveUser(jsonEncode(response.user.toJson()));
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
    await _storage.saveUser(jsonEncode(response.user.toJson()));
    return response.user;
  }

  @override
  Future<void> logout() async {
    await _storage.clearToken();             // ← clearToken not deleteToken
    await _storage.clearUser();
  }

  @override
  Future<String?> getSavedToken() => _storage.getToken(); // ← getToken not readToken

  @override
  Future<User?> getSavedUser() async {
    try {
      final raw = await _storage.getUser();
      if (raw == null || raw.isEmpty) return null;
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Missing/corrupt snapshot (e.g. an install that logged in before
      // user persistence shipped) → degrade to the old null-user behavior.
      return null;
    }
  }
}
