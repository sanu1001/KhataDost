import '../../domain/entities/khata_entry.dart';

/// Abstract khata datasource — repositories and blocs never see the
/// concrete impl (mock vs remote chosen by GetIt comment-swap).
abstract class KhataDatasource {
  Future<Khata> getKhata(String customerId);

  Future<KhataEntry> recordPayment({
    required String customerId,
    required double amount,
  });
}
