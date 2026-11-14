import 'package:equatable/equatable.dart';

/// The fields describing a museum object. All optional: an operator in a
/// hall fills in what the label shows and leaves the rest for the dashboard.
class ObjectMetadata extends Equatable {
  const ObjectMetadata({
    this.inventoryNumber,
    this.material,
    this.period,
    this.heightCm,
    this.widthCm,
    this.depthCm,
  });

  /// Reads the `metadata` object of a published item, or a locally stored
  /// copy of one. Numbers arrive as int or double depending on the value.
  factory ObjectMetadata.fromWire(Map<dynamic, dynamic>? json) {
    if (json == null) return empty;
    return ObjectMetadata(
      inventoryNumber: _text(json['inventory_number']),
      material: _text(json['material']),
      period: _text(json['period']),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      widthCm: (json['width_cm'] as num?)?.toDouble(),
      depthCm: (json['depth_cm'] as num?)?.toDouble(),
    );
  }

  static const empty = ObjectMetadata();

  final String? inventoryNumber;
  final String? material;
  final String? period;
  final double? heightCm;
  final double? widthCm;
  final double? depthCm;

  bool get isEmpty => this == empty;

  bool get hasDimensions =>
      heightCm != null || widthCm != null || depthCm != null;

  /// Only the fields that have a value — the keys the API and the local
  /// stub both use.
  Map<String, dynamic> toWire() {
    return <String, dynamic>{
      'inventory_number': inventoryNumber,
      'material': material,
      'period': period,
      'height_cm': heightCm,
      'width_cm': widthCm,
      'depth_cm': depthCm,
    }..removeWhere((_, value) => value == null);
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [
    inventoryNumber,
    material,
    period,
    heightCm,
    widthCm,
    depthCm,
  ];
}
