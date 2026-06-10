import '../../../domain/entities/item.dart';

final List<Item> kInventorySkeletonItems = [
  const UnitItem(id: 's1', name: 'Placeholder item', variants: [
    ItemVariant(id: 'sv1', label: 'small', price: 10, isDefault: true),
  ]),
  const LooseItem(id: 's2', name: 'Placeholder loose', rate: 20, unit: 'kg'),
  const UnitItem(id: 's3', name: 'Placeholder snack', variants: [
    ItemVariant(id: 'sv2', label: 'regular', price: 30, isDefault: true),
  ]),
  const LooseItem(id: 's4', name: 'Placeholder grain', rate: 60, unit: 'kg'),
  const UnitItem(id: 's5', name: 'Placeholder drink', variants: [
    ItemVariant(id: 'sv3', label: '500ml', price: 25, isDefault: true),
  ]),
  const LooseItem(id: 's6', name: 'Placeholder pulse', rate: 90, unit: 'kg'),
];