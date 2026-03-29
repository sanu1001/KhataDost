import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.shopName,
    required super.email,
    required super.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    shopName: json['shop_name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shop_name': shopName,
    'email': email,
    'phone': phone,
  };
}