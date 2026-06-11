import '../../domain/entities/bill.dart';
import '../../domain/entities/draft_line.dart';
import '../../domain/repositories/billing_repository.dart';
import '../datasources/billing_datasource.dart';

/// Thin forwarding repository — the datasource already speaks domain
/// entities (same shape as the four built features).
class BillingRepositoryImpl implements BillingRepository {
  const BillingRepositoryImpl(this._datasource);

  final BillingDatasource _datasource;

  @override
  Future<Bill> createBill({
    required String? customerId,
    required double amountPaid,
    required List<DraftLine> lines,
  }) =>
      _datasource.createBill(
        customerId: customerId,
        amountPaid: amountPaid,
        lines: lines,
      );

  @override
  Future<List<Bill>> getBills() => _datasource.getBills();

  @override
  Future<Bill> getBillById(String id) => _datasource.getBillById(id);
}
