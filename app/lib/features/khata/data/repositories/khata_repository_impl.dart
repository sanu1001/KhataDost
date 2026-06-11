import '../../domain/entities/khata_entry.dart';
import '../../domain/repositories/khata_repository.dart';
import '../datasources/khata_datasource.dart';

/// Thin forwarding repository — the datasource already speaks domain
/// entities (same shape as the four built features).
class KhataRepositoryImpl implements KhataRepository {
  const KhataRepositoryImpl(this._datasource);

  final KhataDatasource _datasource;

  @override
  Future<Khata> getKhata(String customerId) => _datasource.getKhata(customerId);

  @override
  Future<KhataEntry> recordPayment({
    required String customerId,
    required double amount,
  }) =>
      _datasource.recordPayment(customerId: customerId, amount: amount);
}
