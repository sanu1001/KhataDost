/// Contract for the change-password flow.
///
/// PLACEHOLDER — kept abstract so the UI/bloc can be wired ahead of the API.
/// TODO(you): back this with PUT /v1/auth/password when you build the backend.
abstract class ChangePasswordRepository {
  /// Throws on failure; the BLoC catches and surfaces the message.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
