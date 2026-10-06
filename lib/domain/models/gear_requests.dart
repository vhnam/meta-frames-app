/// Built-in lens created together with a fixed-lens camera.
class FixedLensSpec {
  const FixedLensSpec({
    required this.focalLength,
    required this.maxAperture,
    required this.brand,
    this.model,
  });
  final int focalLength;
  final double maxAperture;
  final String brand;
  final String? model;

  Map<String, dynamic> toJson() => {
    'focalLength': focalLength,
    'maxAperture': maxAperture,
    'brand': brand,
    'model': ?model,
  };
}

class CameraEdit {
  const CameraEdit({
    required this.brand,
    required this.model,
    required this.hasFixedLens,
    this.mount,
    this.description,
    this.fixedLens,
  });
  final String brand, model;
  final bool hasFixedLens;
  final String? mount, description;

  /// Only sent when creating a fixed-lens camera.
  final FixedLensSpec? fixedLens;

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'model': model,
    'mount': ?mount,
    'description': ?description,
    'hasFixedLens': hasFixedLens,
    if (fixedLens != null) 'fixedLens': fixedLens!.toJson(),
  };
}

class LensEdit {
  const LensEdit({
    required this.focalLength,
    required this.maxAperture,
    this.brand,
    this.model,
    this.mount,
    this.description,
  });
  final int focalLength;
  final double maxAperture;
  final String? brand, model, mount, description;

  Map<String, dynamic> toJson() => {
    'brand': ?brand,
    'model': ?model,
    'mount': ?mount,
    'description': ?description,
    'focalLength': focalLength,
    'maxAperture': maxAperture,
  };
}
