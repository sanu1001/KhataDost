import '../../domain/entities/shop_profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_datasource.dart';

/// Concrete repository. Delegates to the datasource (DTO → entity mapping
/// already happens in [ShopProfileModel.fromJson]).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._datasource);

  final SettingsDataSource _datasource;

  @override
  Future<ShopProfile> getProfile() => _datasource.getProfile();
}
