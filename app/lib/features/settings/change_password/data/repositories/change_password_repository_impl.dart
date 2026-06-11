import '../../domain/repositories/change_password_repository.dart';
import '../datasources/change_password_datasource.dart';

/// Concrete repository — delegates to the datasource. Same shape as the
/// settings feature so this slice is ready to flesh out.
class ChangePasswordRepositoryImpl implements ChangePasswordRepository {
  ChangePasswordRepositoryImpl(this._datasource);

  final ChangePasswordDataSource _datasource;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _datasource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}
