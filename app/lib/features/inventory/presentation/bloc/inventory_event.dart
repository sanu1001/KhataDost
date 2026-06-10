part of 'inventory_bloc.dart';

sealed class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class InventoryLoadRequested extends InventoryEvent {
  const InventoryLoadRequested();
}

class ItemAdded extends InventoryEvent {
  final String name;
  final String pricingType;
  final List<ItemVariant>? variants; // unit only
  final double? rate;                // loose only
  final String? unit;                // loose only

  const ItemAdded({
    required this.name,
    required this.pricingType,
    this.variants,
    this.rate,
    this.unit,
  });

  @override
  List<Object?> get props => [name, pricingType, variants, rate, unit];
}

class ItemUpdated extends InventoryEvent {
  final String id;
  final String name;
  final double? rate;
  final String? unit;

  const ItemUpdated({
    required this.id,
    required this.name,
    this.rate,
    this.unit,
  });

  @override
  List<Object?> get props => [id, name, rate, unit];
}

class ItemDeleted extends InventoryEvent {
  final String id;
  const ItemDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class VariantAdded extends InventoryEvent {
  final String itemId;
  final String label;
  final double price;
  final bool isDefault;

  const VariantAdded({
    required this.itemId,
    required this.label,
    required this.price,
    required this.isDefault,
  });

  @override
  List<Object?> get props => [itemId, label, price, isDefault];
}

class VariantUpdated extends InventoryEvent {
  final String itemId;
  final String variantId;
  final String? label;
  final double? price;
  final bool? isDefault;

  const VariantUpdated({
    required this.itemId,
    required this.variantId,
    this.label,
    this.price,
    this.isDefault,
  });

  @override
  List<Object?> get props => [itemId, variantId, label, price, isDefault];
}

class VariantDeleted extends InventoryEvent {
  final String itemId;
  final String variantId;

  const VariantDeleted({required this.itemId, required this.variantId});

  @override
  List<Object?> get props => [itemId, variantId];
}

class InventorySearchChanged extends InventoryEvent {
  final String query;
  const InventorySearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}