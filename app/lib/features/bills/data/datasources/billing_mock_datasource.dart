import '../../../../core/network/api_exception.dart';
import '../../domain/bill_math.dart' as bm;
import '../../domain/entities/bill.dart';
import '../../domain/entities/draft_line.dart';
import 'billing_datasource.dart';

/// In-memory billing datasource. STAYS IN-TREE FOREVER (tests + portfolio);
/// swap to remote via the GetIt comment-swap, never delete this.
///
/// Mirrors the SERVER's settlement rules and exact error messages
/// (`billing_service.go` sentinels) so the inline-error UX is fully
/// testable offline — including the walk-in 409.
class BillingMockDatasource implements BillingDatasource {
  /// Names matching the customers mock (c1–c4) for the header snapshot.
  static const _customerNames = <String, String>{
    'c1': 'Anil Sen',
    'c2': 'Meena Devi',
    'c3': 'Suresh Sen',
    'c4': 'Sunita Kumari',
  };

  final List<Bill> _bills = [
    // Seed: one credit bill (Anil owes) and one walk-in cash bill.
    Bill(
      id: 'b1',
      customerId: 'c1',
      customerName: 'Anil Sen',
      amount: 65,
      amountPaid: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      items: const [
        BillItem(
          id: 'bi1',
          itemId: 'i1',
          variantId: 'v3',
          name: 'Lays',
          quantity: 1,
          unitPrice: 50,
          lineTotal: 50,
        ),
        BillItem(
          id: 'bi2',
          itemId: 'i3',
          variantId: null,
          name: 'Sugar',
          quantity: 0.75,
          unitPrice: 20,
          lineTotal: 15,
        ),
      ],
    ),
    Bill(
      id: 'b2',
      customerId: null,
      customerName: 'Walk-in',
      amount: 20,
      amountPaid: 20,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      items: const [
        BillItem(
          id: 'bi3',
          itemId: 'i1',
          variantId: 'v2',
          name: 'Lays',
          quantity: 1,
          unitPrice: 20,
          lineTotal: 20,
        ),
      ],
    ),
  ];

  @override
  Future<Bill> createBill({
    required String? customerId,
    required double amountPaid,
    required List<DraftLine> lines,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // ── Server-rule mirror (same order, same messages) ───────────────────
    if (lines.isEmpty) {
      throw const ApiException('items are required', statusCode: 400);
    }
    for (final l in lines) {
      if (l.name.trim().isEmpty || l.quantity <= 0 || l.unitPrice < 0) {
        throw const ApiException(
          'each item needs a name, a positive quantity, and a non-negative price',
          statusCode: 400,
        );
      }
    }
    if (amountPaid < 0) {
      throw const ApiException('amount_paid cannot be negative',
          statusCode: 400);
    }

    // Server-side money math (client figures are advisory).
    final total = bm.billTotal(
      lines.map((l) => bm.lineTotal(l.quantity, l.unitPrice)),
    );

    String customerName;
    if (customerId == null) {
      if (amountPaid != total) {
        throw const ApiException('a walk-in bill must be paid in full',
            statusCode: 409);
      }
      customerName = 'Walk-in';
    } else {
      // Permissive on FOREIGN ids: with mock billing + real customers the
      // picker hands us real DB uuids this mock can't know. Business rules
      // (409/400) stay enforced; ownership 404s are the real server's job
      // (Bruno-covered).
      customerName = _customerNames[customerId] ?? 'Customer';
    }

    final billId = DateTime.now().millisecondsSinceEpoch.toString();
    var i = 0;
    final bill = Bill(
      id: billId,
      customerId: customerId,
      customerName: customerName,
      amount: total,
      amountPaid: amountPaid,
      createdAt: DateTime.now(),
      items: [
        for (final l in lines)
          BillItem(
            id: '$billId-${i++}',
            itemId: l.itemId,
            variantId: l.variantId,
            name: l.name,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            lineTotal: bm.lineTotal(l.quantity, l.unitPrice),
          ),
      ],
    );

    _bills.add(bill);
    return bill;
  }

  @override
  Future<List<Bill>> getBills() async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Headers only, newest first — same shape as GET /v1/bills.
    final sorted = [..._bills]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final b in sorted)
        Bill(
          id: b.id,
          customerId: b.customerId,
          customerName: b.customerName,
          amount: b.amount,
          amountPaid: b.amountPaid,
          createdAt: b.createdAt,
          items: const [],
        ),
    ];
  }

  @override
  Future<Bill> getBillById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _bills.indexWhere((b) => b.id == id);
    if (index == -1) {
      throw const ApiException('bill not found', statusCode: 404);
    }
    return _bills[index];
  }
}
