import '../../domain/entities/shop_profile.dart';

/// Datasource contract. Implementations: mock (in-memory) and remote (Dio).
/// Swapping mock → remote is one line change in `core/di/injection.dart`.
abstract class SettingsDataSource {
  Future<ShopProfile> getProfile();
}
