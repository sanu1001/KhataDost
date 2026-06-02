import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final bool hasDues;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    required this.hasDues,
  });

  @override
  List<Object?> get props => [id, name, phone, email, notes, hasDues];
}