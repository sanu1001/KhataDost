import '../../../../core/network/api_exception.dart';
import '../../../bills/domain/bill_math.dart' as bm;
import '../../domain/entities/khata_entry.dart';
import '../../domain/khata_math.dart' as km;
import 'khata_datasource.dart';

/// In-memory khata datasource. STAYS IN-TREE FOREVER (tests + portfolio);
/// swap to remote via the GetIt comment-swap, never delete this.
///
/// Mirrors the SERVER's rules and exact messages (`khata_service.go`
/// sentinels) so the inline-error UX is fully testable offline. Balance
/// is DERIVED here too (km.balanceOf) — the mock has no stored balance,
/// same integrity rule as production (§12).
///
/// Seeds are coherent with the sibling mocks:
/// - c1 Anil Sen: credit ₹65 linked to the billing mock's bill `b1`
///   (tappable → its Lays + Sugar items) + payment ₹20 → balance 45,
///   matching his `hasDues: true` in the customers mock.
/// - c4 Sunita Kumari: credit ₹30 with `billId: null` (its bill was
///   "deleted" — ON DELETE SET NULL) → exercises the plain,
///   non-tappable credit row. Balance 30, matching `hasDues: true`.
/// - c2 / c3: empty ledgers → the empty-state UX.
class KhataMockDatasource implements KhataDatasource {
  final Map<String, List<KhataEntry>> _ledgers = {
    'c1': [
      KhataEntry(
        id: 'k1',
        type: KhataEntryType.credit,
        amount: 65,
        billId: 'b1',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      KhataEntry(
        id: 'k2',
        type: KhataEntryType.payment,
        amount: 20,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ],
    'c4': [
      KhataEntry(
        id: 'k3',
        type: KhataEntryType.credit,
        amount: 30,
        billId: null, // dead bill link — renders plain, not tappable
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
  };

  @override
  Future<Khata> getKhata(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Permissive on FOREIGN ids (same stance as the billing mock): with
    // mock khata + real customers, real DB uuids arrive — they get an
    // empty ledger. Ownership 404s are the real server's job
    // (Bruno-covered).
    final entries = List<KhataEntry>.unmodifiable(
      _ledgers[customerId] ?? const <KhataEntry>[],
    );
    return Khata(balance: km.balanceOf(entries), entries: entries);
  }

  @override
  Future<KhataEntry> recordPayment({
    required String customerId,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // ── Server-rule mirror (same check, same message, same status) ───────
    if (amount <= 0) {
      throw const ApiException(km.nonPositivePaymentMessage, statusCode: 400);
    }

    final entry = KhataEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: KhataEntryType.payment,
      amount: bm.round2(amount), // server rounds before insert
      createdAt: DateTime.now(),
    );

    _ledgers.putIfAbsent(customerId, () => <KhataEntry>[]).add(entry);
    return entry;
  }
}
