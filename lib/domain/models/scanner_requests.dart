import 'models.dart';

/// A scanner as saved. The server replaces every field, so one left out here
/// is cleared.
class ScannerEdit {
  const ScannerEdit({
    required this.brand,
    this.model,
    this.kind,
    this.notes,
    required this.defaultSettings,
  });
  final String brand;
  final String? model, notes;
  final ScannerKind? kind;
  final Map<String, Object?> defaultSettings;

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'model': ?model,
    'kind': ?kind?.wire,
    'notes': ?notes,
    'defaultSettings': defaultSettings,
  };
}
