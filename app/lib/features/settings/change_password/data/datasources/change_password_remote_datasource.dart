import 'change_password_datasource.dart';

/// PLACEHOLDER remote datasource.
///
/// TODO(you): real Dio call to PUT /v1/auth/password. Follow
/// features/settings/data/datasources/settings_remote_datasource.dart for the
/// DioClient + ApiException + dio_error_mapper pattern. For now this throws so
/// the wired-up flow lands in a graceful "not implemented" failure state.
class ChangePasswordRemoteDataSource implements ChangePasswordDataSource {
  const ChangePasswordRemoteDataSource();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    throw UnimplementedError(
      'Change password is not implemented yet — wire PUT /v1/auth/password.',
    );
  }
}
