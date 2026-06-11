import '../../domain/entities/shop_profile.dart';

/// JSON ⇄ entity for GET /v1/me. Extends the entity so callers stay agnostic
/// to whether the data came from the mock or the network.
class ShopProfileModel extends ShopProfile {
  const ShopProfileModel({
    required super.id,
    required super.name,
    required super.shopName,
    required super.email,
    required super.phone,
  });

  factory ShopProfileModel.fromJson(Map<String, dynamic> json) =>
      ShopProfileModel(
        id: json['id'] as String,
        name: json['name'] as String,
        shopName: json['shop_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
      );
}
