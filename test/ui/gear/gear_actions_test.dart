import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';

void main() {
  test('camera and lens requests only send what is set', () {
    expect(const LensEdit(focalLength: 35, maxAperture: 2).toJson(), {
      'focalLength': 35,
      'maxAperture': 2.0,
    });
    final json = const CameraEdit(
      brand: 'Ricoh',
      model: 'GR',
      hasFixedLens: true,
      fixedLens: FixedLensSpec(
        focalLength: 28,
        maxAperture: 2.8,
        brand: 'Ricoh',
      ),
    ).toJson();
    expect(json.containsKey('mount'), isFalse);
    expect(json['fixedLens'], {
      'focalLength': 28,
      'maxAperture': 2.8,
      'brand': 'Ricoh',
    });
  });
}
