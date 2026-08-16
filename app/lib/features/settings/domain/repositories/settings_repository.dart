import '../entities/shop_profile.dart';

/// Contract every settings repository must satisfy.
/// The BLoC only ever talks to this — never to Dio, storage, or any package.
abstract class SettingsRepository {
  /// Fetches the authenticated shopkeeper's profile (GET /v1/me).
  /// Throws on failure; the BLoC catches and surfaces the message.
  Future<ShopProfile> getProfile();
}
