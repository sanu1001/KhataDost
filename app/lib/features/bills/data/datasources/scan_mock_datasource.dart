import '../../../inventory/domain/entities/item.dart';
import '../../domain/entities/scan_result.dart';
import 'scan_datasource.dart';

/// Canned scan results. STAYS IN-TREE FOREVER — swap via GetIt
/// comment-swap, never delete.
///
/// The returned cards MIRROR the inventory mock's items (i1 Lays, i2
/// Colgate) so on full-mock wiring the matched lines look exactly like
/// manual adds from the same inventory. One unmatched label exercises the
/// misc-line prefill path. The image is ignored.
class ScanMockDatasource implements ScanDatasource {
  static const _lays = UnitItem(
    id: 'i1',
    name: 'Lays',
    variants: [
      ItemVariant(id: 'v1', label: 'small', price: 10, isDefault: true),
      ItemVariant(id: 'v2', label: 'medium', price: 20, isDefault: false),
      ItemVariant(id: 'v3', label: 'large', price: 50, isDefault: false),
    ],
  );

  static const _colgate = UnitItem(
    id: 'i2',
    name: 'Colgate',
    variants: [
      ItemVariant(id: 'v4', label: '100g', price: 55, isDefault: true),
      ItemVariant(id: 'v5', label: '200g', price: 95, isDefault: false),
    ],
  );

  @override
  Future<ScanResult> scan({
    required String imageBase64,
    required String mimeType,
  }) async {
    // A real scan takes a few seconds — make the mock feel honest.
    await Future.delayed(const Duration(milliseconds: 900));

    return const ScanResult(
      matches: [
        ScanMatch(
          detectedLabel: 'Lays Magic Masala',
          detectedQuantity: 2,
          defaultVariantId: 'v1',
          item: _lays,
        ),
        ScanMatch(
          detectedLabel: 'Colgate MaxFresh',
          detectedQuantity: 1,
          defaultVariantId: 'v4',
          item: _colgate,
        ),
      ],
      unmatched: [
        UnmatchedDetection(label: 'POP Popcorn', quantity: 1),
      ],
    );
  }
}
