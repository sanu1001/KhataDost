/// Datasource contract for the change-password flow (placeholder).
/// Implement a mock + remote pair here, mirroring the settings feature, when
/// you build the real endpoint.
abstract class ChangePasswordDataSource {
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
