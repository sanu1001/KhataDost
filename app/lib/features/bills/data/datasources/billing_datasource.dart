import '../../domain/entities/bill.dart';
import '../../domain/entities/draft_line.dart';

/// Abstract billing datasource — repositories and blocs never see the
/// concrete impl (mock vs remote chosen by GetIt comment-swap).
abstract class BillingDatasource {
  Future<Bill> createBill({
    required String? customerId,
    required double amountPaid,
    required List<DraftLine> lines,
  });

  Future<List<Bill>> getBills();

  Future<Bill> getBillById(String id);
}
