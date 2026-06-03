import 'package:khata_dost/features/inventory/data/datasources/inventory_datasource.dart';
import '../../domain/entities/item.dart';
import '../models/inventory_model.dart';

class InventoryMockDatasource implements InventoryDatasource{

  final List<Item> _items = [
    const UnitItemModel(
      id: 'i1',
      name: 'Lays',
      variants: [
        ItemVariantModel(id: 'v1', label: 'small',  price: 10, isDefault: true),
        ItemVariantModel(id: 'v2', label: 'medium', price: 20, isDefault: false),
        ItemVariantModel(id: 'v3', label: 'large',  price: 50, isDefault: false),
      ],
    ),
    const UnitItemModel(
      id: 'i2',
      name: 'Colgate',
      variants: [
        ItemVariantModel(id: 'v4', label: '100g', price: 55, isDefault: true),
        ItemVariantModel(id: 'v5', label: '200g', price: 95, isDefault: false),
      ],
    ),
    const LooseItemModel(id: 'i3', name: 'Sugar', rate: 20, unit: 'kg'),
    const LooseItemModel(id: 'i4', name: 'Rice',  rate: 60, unit: 'kg'),
  ];


  @override
  Future<List<Item>> getItems() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [..._items]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Item> createItem({required String name, required String pricingType, List<ItemVariant>? variants, double? rate, String? unit}) async {

    await Future.delayed(const Duration(milliseconds: 400));


    if(pricingType == 'unit'){
      final unitItemModel =  UnitItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        variants: variants!,
      );
      _items.add(unitItemModel);
      return unitItemModel;
    }
    else{
      final looseItemModel = LooseItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        rate: rate!,
        unit: unit!,
      );
      _items.add(looseItemModel);
      return looseItemModel;
    }
  }
  @override
  Future<Item> updateItem({required String name, required String id , double? rate, String? unit}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) throw Exception('Item not found');

    final item = _items[index];
    if(item is UnitItemModel){
      final updated = UnitItemModel(id: id, name: name, variants: item.variants);
      _items[index] = updated;
      return updated;
    }
    else{
      final updated = LooseItemModel(id: id, name: name, rate: rate!, unit: unit!);
      _items[index] = updated;
      return updated;
    }
  }

  @override
  Future<void> deleteItem({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<Item> addVariant({required String itemId, required String label, required double price, required bool isDefault}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _items.indexWhere((i) => i.id == itemId);
    if(index == -1) throw Exception('Item of this variant not found for adding');

    final item = _items[index];
    if(item is! UnitItemModel){
      throw Exception('Cannot add variant for loose items');
    }
    final newVariant = ItemVariantModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      price: price,
      isDefault: isDefault,
    );
    final updated = UnitItemModel(
      id: item.id,
      name: item.name,
      variants: [...item.variants, newVariant],
    );
    _items[index] = updated;
    return updated;

  }
  @override
  Future<Item> updateVariant({required String itemId, required String variantId , String? label, double? price, bool? isDefault}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _items.indexWhere((i) => i.id == itemId);
    if(index == -1) throw Exception('Item of this variant not found for updating');

    final item = _items[index];
    if(item is! UnitItemModel){
      throw Exception('Cannot update variant for loose items');
    }

    final varIndex = item.variants.indexWhere((i) => i.id == variantId);
    if(varIndex == -1) throw Exception('This Variant does not exist for this item');

    final updatedVar = ItemVariantModel(
        id: variantId,
        label: label!,
        isDefault: isDefault!,
        price: price!
    );

    final updatedItem = UnitItemModel(
        id: item.id,
        name: item.name,
        variants: item.variants.map((v) => v.id == variantId ? updatedVar : v).toList(),
    );

    _items[index] = updatedItem;
    return updatedItem;

  }

  @override
  Future<Item> deleteVariant({required String itemId , required String variantId}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _items.indexWhere((i) => i.id == itemId);
    if(index == -1) throw Exception('Item not found');

    final item = _items[index];
    if (item is! UnitItemModel) {
      throw Exception('Cannot delete variant for loose items');
    }

    final updated = UnitItemModel(
      id: item.id,
      name: item.name,
      variants: item.variants.where((v) => v.id != variantId).toList(),
    );
    _items[index] = updated;
    return updated;
  }
}