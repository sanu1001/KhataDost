import '../../../inventory/data/models/inventory_model.dart';
import '../../domain/entities/scan_result.dart';

/// `POST /v1/scan` response parsing. The nested `item` mirrors the
/// inventory endpoints' card JSON exactly, so it rides through the
/// EXISTING `itemFromJson` polymorphic dispatch — no parallel item model.
class ScanResultModel extends ScanResult {
  const ScanResultModel({required super.matches, required super.unmatched});

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      matches: (json['matches'] as List<dynamic>? ?? const [])
          .map((e) => ScanMatchModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      unmatched: (json['unmatched'] as List<dynamic>? ?? const [])
          .map((e) =>
              UnmatchedDetectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ScanMatchModel extends ScanMatch {
  const ScanMatchModel({
    required super.detectedLabel,
    required super.detectedQuantity,
    required super.defaultVariantId,
    required super.item,
  });

  factory ScanMatchModel.fromJson(Map<String, dynamic> json) {
    return ScanMatchModel(
      detectedLabel: json['detected_label'] as String,
      detectedQuantity: (json['detected_quantity'] as num).toInt(),
      defaultVariantId: json['default_variant_id'] as String,
      item: itemFromJson(json['item'] as Map<String, dynamic>),
    );
  }
}

class UnmatchedDetectionModel extends UnmatchedDetection {
  const UnmatchedDetectionModel({required super.label, required super.quantity});

  factory UnmatchedDetectionModel.fromJson(Map<String, dynamic> json) {
    return UnmatchedDetectionModel(
      label: json['label'] as String,
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}
