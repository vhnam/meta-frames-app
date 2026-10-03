import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/gear_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/gear/view_models/gear_actions.dart';

import '../../testing/fakes.dart';

void main() {
  late FakeCameraRepository cameras;
  late ProviderContainer container;

  setUp(() {
    cameras = FakeCameraRepository(
      cameraList: [camera('c1'), camera('c2'), camera('c3')],
      linked: {
        'c1': [lens('keep'), lens('new')],
        'c2': [lens('keep')],
        'c3': [lens('keep')],
      },
    );
    container = ProviderContainer(
      overrides: [
        cameraRepositoryProvider.overrideWithValue(cameras),
        lensRepositoryProvider.overrideWithValue(
          FakeLensRepository([lens('keep'), lens('new')]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  const edit = LensEdit(focalLength: 50, maxAperture: 1.8);

  test('a new lens is added only to the cameras ticked in the form', () async {
    await container
        .read(lensActionsProvider)
        .save(
          edit,
          links: LensLinks(
            cameras: [camera('c1'), camera('c2'), camera('c3')],
            wanted: {'c2'},
            initial: const {},
          ),
        );

    expect(cameras.lensWrites.keys, ['c2']);
    expect(cameras.lensWrites['c2'], unorderedEquals(['keep', 'new']));
  });

  test('editing adds and removes links, and skips unchanged cameras', () async {
    await container
        .read(lensActionsProvider)
        .save(
          edit,
          existing: lens('new'),
          links: LensLinks(
            cameras: [camera('c1'), camera('c2'), camera('c3')],
            // c1 unticked, c2 newly ticked, c3 not ticked before or now.
            wanted: {'c2'},
            initial: {'c1'},
          ),
        );

    expect(cameras.lensWrites.keys.toSet(), {'c1', 'c2'});
    expect(cameras.lensWrites['c1'], ['keep']);
    expect(cameras.lensWrites['c2'], unorderedEquals(['keep', 'new']));
  });

  test('a built-in lens (no links) touches no cameras', () async {
    await container.read(lensActionsProvider).save(edit);
    expect(cameras.lensWrites, isEmpty);
  });

  test(
    'saving a camera links lenses only when it takes interchangeable lenses',
    () async {
      final actions = container.read(cameraActionsProvider);
      const interchangeable = CameraEdit(
        brand: 'Nikon',
        model: 'FM2',
        hasFixedLens: false,
        mount: 'F',
      );
      await actions.save(interchangeable, lensIds: {'keep'});
      expect(cameras.lensWrites['new'], ['keep']);

      cameras.lensWrites.clear();
      const fixed = CameraEdit(
        brand: 'Ricoh',
        model: 'GR',
        hasFixedLens: true,
        fixedLens: FixedLensSpec(
          focalLength: 28,
          maxAperture: 2.8,
          brand: 'Ricoh',
        ),
      );
      await actions.save(fixed, lensIds: {'keep'});
      expect(cameras.lensWrites, isEmpty);

      await actions.save(interchangeable);
      expect(cameras.lensWrites, isEmpty, reason: 'null leaves links alone');
    },
  );

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
