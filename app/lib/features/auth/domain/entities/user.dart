import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
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