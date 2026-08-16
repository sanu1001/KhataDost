import '../entities/scan_result.dart';

/// Contract for the scan on-ramp (`POST /v1/scan`). Stateless: a scan is
/// a suggestion, nothing is persisted, re-scan costs nothing but quota.
abstract class ScanRepository {
  /// [imageBase64] is the captured JPEG, base64-encoded by the caller.
  /// 429/504 (quota/timeout) arrive as ApiException with the server's
  /// friendly "try again" message — graceful-degradation cases, not bugs.
  Future<ScanResult> scan({
    required String imageBase64,
    required String mimeType,
  });
}
