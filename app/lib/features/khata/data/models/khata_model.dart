import '../../domain/entities/khata_entry.dart';

/// Parses the server's khataEntryResponse. Money fields are JSON
/// numbers (`(json[...] as num).toDouble()` — ints like `65` arrive
/// without a decimal point); `bill_id`/`note` are JSON null when absent;
/// `created_at` is RFC 3339.
class KhataEntryModel extends KhataEntry {
  const KhataEntryModel({
    required super.id,
    required super.type,
    required super.amount,
    super.billId,
    super.note,
    required super.createdAt,
  });

  factory KhataEntryModel.fromJson(Map<String, dynamic> json) {
    return KhataEntryModel(
      id: json['id'] as String,
      type: _typeFromJson(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      billId: json['bill_id'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// The `GET /v1/khata/{customerId}` body: `{balance, entries}`.
///
/// NOTE the `.map(...).toList()` below: at runtime [Khata.entries] is a
/// `List<KhataEntryModel>` inside the `List<KhataEntry>` field — the
/// covariant-list trap. Lookups on it must stay loop-based; never
/// `firstWhere`/`singleWhere` with `orElse` (regression group in
/// khata_math_test.dart).
class KhataModel extends Khata {
  const KhataModel({required super.balance, required super.entries});

  factory KhataModel.fromJson(Map<String, dynamic> json) {
    return KhataModel(
      balance: (json['balance'] as num).toDouble(),
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map((e) => KhataEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Strict: the server only ever emits 'credit' | 'payment' — anything
/// else is a contract break worth crashing loudly over (same fail-fast
/// stance as the frozen models' unguarded casts).
KhataEntryType _typeFromJson(String s) {
  switch (s) {
    case 'credit':
      return KhataEntryType.credit;
    case 'payment':
      return KhataEntryType.payment;
  }
  throw ArgumentError.value(s, 'type', "expected 'credit' or 'payment'");
}
