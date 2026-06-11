import '../../domain/entities/shop_profile.dart';
import '../models/shop_profile_model.dart';
import 'settings_datasource.dart';

/// In-memory mock for the profile fetch.
/// Kept in-tree forever — flip the comment in `injection.dart` to roll back
/// to this for tests / offline UI work. Never deleted.
class SettingsMockDatasource implements SettingsDataSource {
  const SettingsMockDatasource();

  @override
  Future<ShopProfile> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const ShopProfileModel(
      id: 'mock-user-id',
      name: 'Ramesh',
      shopName: 'Ramesh Kirana',
      email: 'ramesh@example.com',
      phone: '9876543210',
    );
  }
}
