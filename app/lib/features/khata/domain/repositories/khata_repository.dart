import '../entities/khata_entry.dart';

/// Contract for the khata ledger reads + the ONE balance-down action.
/// Append-only by construction: there is no update or delete, and no way
/// to write a balance — only entries (§12 integrity rule).
abstract class KhataRepository {
  /// `GET /v1/khata/{customerId}` — server-derived balance + the full
  /// entry timeline, oldest first. 404 (foreign/unknown customer)
  /// surfaces as ApiException.
  Future<Khata> getKhata(String customerId);

  /// `POST /v1/khata/{customerId}/payment` — writes a `payment` entry
  /// and returns it. Server 400 (non-positive amount) and 404 surface as
  /// ApiException with the server's message for inline display.
  Future<KhataEntry> recordPayment({
    required String customerId,
    required double amount,
  });
}
