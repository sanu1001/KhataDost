import 'package:khata_dost/features/inventory/domain/entities/item.dart';


Item itemFromJson(Map<String, dynamic> json) {
  if (json['pricing_type'] == 'unit') return UnitItemModel.fromJson(json);
  return LooseItemModel.fromJson(json);
}

// Map<String, dynamic> itemToJson(Map<String, dynamic> json) {
//   if(json['pricing_type'] == 'unit') return UnitItemModel.toJson();
//   return LooseItemModel.toJson();
// } not needed wrong lol.


class UnitItemModel extends UnitItem{
  const UnitItemModel({required super.id, required super.name, required super.variants});

  factory UnitItemModel.fromJson(Map<String, dynamic> json){
    return UnitItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      variants: (json['variants'] as List<dynamic>).map((v) => ItemVariantModel.fromJson(v as Map<String, dynamic>)).toList(),
    );
  }

  Map<String , dynamic> toJson() {
    return{
      'name' : name,
      'pricing_type': 'unit',
      'variants' : variants.map((v) => (v as ItemVariantModel).toJson()).toList(),
    };
  }
}

class LooseItemModel extends LooseItem{
  const LooseItemModel({required super.id, required super.name, required super.rate, required super.unit});

  factory LooseItemModel.fromJson(Map<String, dynamic> json){
    return LooseItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      rate: (json['rate'] as num).toDouble(),
      unit: json['unit'] as String
    );
  }

  Map<String, dynamic> toJson() {
    return{
      'name' : name,
      'pricing_type' : 'loose',
      'rate' : rate,
      'unit' : unit,
    };
  }
}

class ItemVariantModel extends ItemVariant{
  const ItemVariantModel({required super.id, required super.label, required super.price, required super.isDefault});

  factory ItemVariantModel.fromJson(Map<String, dynamic> json){
    return ItemVariantModel(
        id: json['id'] as String,
        label: json['label'] as String,
        price: (json['price'] as num).toDouble() ,
        isDefault: json['is_default'] as bool
    );
  }

  Map<String, dynamic> toJson() {
    return{
      'label': label,
      'price': price,
      'is_default' : isDefault
    };
  }

}