import 'package:equatable/equatable.dart';

/// Read-only shop/owner profile shown on the Settings page.
/// Sourced from GET /v1/me (never from the JWT — the token carries only `sub`).
class ShopProfile extends Equatable {
  const ShopProfile({
    required this.id,
    required this.name,
    required this.shopName,
    required this.email,
    required this.phone,
  });

  final String id;
  final String name;
  final String shopName;
  final String email;
  final String phone;

  @override
  List<Object?> get props => [id, name, shopName, email, phone];
}
