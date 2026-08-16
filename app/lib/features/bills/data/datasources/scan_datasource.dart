import '../../domain/entities/scan_result.dart';

/// Abstract scan datasource — mock vs remote chosen by GetIt comment-swap.
abstract class ScanDatasource {
  Future<ScanResult> scan({
    required String imageBase64,
    required String mimeType,
  });
}
