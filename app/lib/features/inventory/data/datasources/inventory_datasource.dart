import '../../domain/entities/item.dart';

abstract class InventoryDatasource {
  Future<List<Item>> getItems();

  Future<Item> createItem({
    required String name,
    required String pricingType,
    List<ItemVariant>? variants, // unit only
    double? rate,                // loose only
    String? unit,                // loose only
  });

  Future<Item> updateItem({
    required String id,
    required String name,
    double? rate, // loose only
    String? unit, // loose only
  });

  Future<void> deleteItem({required String id});

  Future<Item> addVariant({
    required String itemId,
    required String label,
    required double price,
    required bool isDefault,
  });

  Future<Item> updateVariant({
    required String itemId,
    required String variantId,
    String? label,
    double? price,
    bool? isDefault,
  });

  Future<Item> deleteVariant({required String itemId, required String variantId}); // ← was void
}