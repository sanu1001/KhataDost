import 'package:khata_dost/features/inventory/data/datasources/inventory_datasource.dart';
import 'package:khata_dost/features/inventory/domain/repository/inventory_repository.dart';

import '../../domain/entities/item.dart';

class InventoryRepositoryImpl implements InventoryRepository{
  final InventoryDatasource _datasource;

  const InventoryRepositoryImpl(this._datasource);

  @override
  Future<List<Item>> getItems(){
    return _datasource.getItems();
  }

  @override
  Future<Item> createItem({
    required String name, required String pricingType,
    List<ItemVariant>? variants, double? rate, String? unit,
  }){
    return _datasource.createItem(name: name, pricingType: pricingType, variants: variants, rate: rate, unit: unit);
  }

  @override
  Future<Item> updateItem({
    required String id,
    required String name,
    double? rate, // loose only
    String? unit, // loose only
  }){
    return _datasource.updateItem(id: id, name: name, rate: rate, unit: unit);
  }

  @override
  Future<void> deleteItem({required String id}) => _datasource.deleteItem(id: id);

  @override
  Future<ItemVariant> addVariant({
    required String itemId,
    required String label,
    required double price,
    required bool isDefault,
  }) => _datasource.addVariant(itemId: itemId, label: label, price: price, isDefault: isDefault);

  @override
  Future<ItemVariant> updateVariant({
    required String itemId,
    required String variantId,
    String? label,
    double? price,
    bool? isDefault,
  }) => _datasource.updateVariant(itemId: itemId, variantId: variantId, label: label, price: price, isDefault: isDefault);

  @override
  Future<void> deleteVariant({required String itemId, required String variantId}) => _datasource.deleteVariant(itemId: itemId, variantId: variantId);


}