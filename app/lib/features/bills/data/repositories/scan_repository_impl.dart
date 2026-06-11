import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/scan_repository.dart';
import '../datasources/scan_datasource.dart';

class ScanRepositoryImpl implements ScanRepository {
  const ScanRepositoryImpl(this._datasource);

  final ScanDatasource _datasource;

  @override
  Future<ScanResult> scan({
    required String imageBase64,
    required String mimeType,
  }) =>
      _datasource.scan(imageBase64: imageBase64, mimeType: mimeType);
}
