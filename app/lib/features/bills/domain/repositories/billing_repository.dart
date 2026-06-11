import '../entities/bill.dart';
import '../entities/draft_line.dart';

/// Contract for bill persistence. Implementations map [DraftLine]s to the
/// `POST /v1/bills` line shape — the server recomputes all money figures
/// and answers with the persisted [Bill].
abstract class BillingRepository {
  /// Create + settle in one shot. [customerId] null = walk-in.
  /// [amountPaid] is always sent explicitly ("paying now", pre-filled to
  /// the bill total). Server errors (409 walk-in-must-pay-full, 400, 404)
  /// surface as ApiException with the server's message.
  Future<Bill> createBill({
    required String? customerId,
    required double amountPaid,
    required List<DraftLine> lines,
  });

  /// Headers only, newest first (`items` empty).
  Future<List<Bill>> getBills();

  /// Header + nested items.
  Future<Bill> getBillById(String id);
}
