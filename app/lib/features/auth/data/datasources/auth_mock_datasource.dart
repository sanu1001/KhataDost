import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'auth_datasource.dart';   // ← implements the interface now
import 'auth_exception.dart';

class AuthMockDatasource implements AuthDataSource {  // ← implements added
  static const _validAccessCode = 'KHATA2025';

  final Set<String> _registeredEmails = {};

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return AuthResponseModel(
      token: 'mock.jwt.token',
      user: UserModel(
        id: 'mock-user-id',
        name: 'Demo User',
        shopName: 'Demo Shop',
        email: email,
        phone: '9999999999',
      ),
    );
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String shopName,
    required String phone,
    required String email,
    required String password,
    required String accessCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    if (accessCode != _validAccessCode) {
      throw const AuthException('Invalid access code');
    }

    if (_registeredEmails.contains(email.toLowerCase())) {
      throw const AuthException('An account with this email already exists');
    }

    _registeredEmails.add(email.toLowerCase());

    return AuthResponseModel(
      token: 'mock.jwt.token',
      user: UserModel(
        id: 'mock-user-id',
        name: name,
        shopName: shopName,
        email: email,
        phone: phone,
      ),
    );
  }
}