import 'package:equatable/equatable.dart';

sealed class Item extends Equatable {
  final String id;
  final String name;
  const Item({required this.id, required this.name });

  @override
  List<Object?> get props => [id, name];
}

class UnitItem extends Item {
  final List<ItemVariant> variants;
  const UnitItem({required super.id, required super.name ,required this.variants});

  @override
  List<Object?> get props => [id, name, variants];
}

class LooseItem extends Item {
  final double rate;
  final String unit;
  const LooseItem({required super.id, required super.name, required this.unit, required this.rate});

  @override
  List<Object?> get props => [id, name, rate, unit];
}

class ItemVariant extends Equatable {
  final String id;
  final String label;
  final double price;
  final bool isDefault;
  const ItemVariant({required this.id, required this.label, required this.isDefault, required this.price});
  @override
  List<Object?> get props => [id, label, price, isDefault];
}