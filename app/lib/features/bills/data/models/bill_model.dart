import '../../domain/entities/bill.dart';

class BillModel extends Bill {
  const BillModel({
    required super.id,
    required super.customerId,
    required super.customerName,
    required super.amount,
    required super.amountPaid,
    required super.createdAt,
    required super.items,
  });

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      amountPaid: (json['amount_paid'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      // Empty in list responses; populated on create/detail.
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => BillItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BillItemModel extends BillItem {
  const BillItemModel({
    required super.id,
    required super.itemId,
    required super.variantId,
    required super.name,
    required super.quantity,
    required super.unitPrice,
    required super.lineTotal,
  });

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      id: json['id'] as String,
      itemId: json['item_id'] as String?,
      variantId: json['variant_id'] as String?,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }
}
