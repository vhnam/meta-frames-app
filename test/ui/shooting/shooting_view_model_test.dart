import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/shooting/view_models/shooting_view_model.dart';

import '../../testing/fakes.dart';

void main() {
  late FakeRollRepository rolls;

  ProviderContainer containerWith({List<Camera> cams = const []}) {
    final c = ProviderContainer(
      overrides: [
        cameraRepositoryProvider.overrideWithValue(
          FakeCameraRepository(cameraList: [...cams]),
        ),
        rollRepositoryProvider.overrideWithValue(rolls),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => rolls = FakeRollRepository([]));

  test('every camera holding a roll is listed, active or not', () async {
    final c = containerWith(
      cams: [
        camera('fm2', loaded: true),
        camera('xa', loaded: true),
        camera('empty'),
        // Older data can leave a roll in a camera that was since retired. It
        // must stay findable so the roll can be finished.
        camera('retired', active: false, loaded: true),
      ],
    );
    final sub = c.listen(loadedCamerasProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(camerasProvider.future);

    expect(c.read(loadedCamerasProvider).requireValue.map((x) => x.id), [
      'fm2',
      'xa',
      'retired',
    ]);
  });

  test('only active cameras with nothing in them can be loaded', () async {
    final c = containerWith(
      cams: [
        camera('fm2', loaded: true),
        camera('empty'),
        camera('off', active: false),
      ],
    );
    final sub = c.listen(emptyCamerasProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(camerasProvider.future);

    expect(c.read(emptyCamerasProvider).requireValue.map((x) => x.id), [
      'empty',
    ]);
  });

  test('a user with no cameras and no rolls is new', () async {
    final c = containerWith();
    final sub = c.listen(isNewUserProvider, (_, _) {});
    addTearDown(sub.close);
    expect(c.read(isNewUserProvider), isFalse, reason: 'still loading');
    await c.read(camerasProvider.future);
    await c.read(rollsProvider(RollFilter.empty).future);
    expect(c.read(isNewUserProvider), isTrue);
  });

  test('having any roll or camera is not new', () async {
    final c = containerWith(cams: [camera('c1')]);
    final sub = c.listen(isNewUserProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(camerasProvider.future);
    await c.read(rollsProvider(RollFilter.empty).future);
    expect(c.read(isNewUserProvider), isFalse);
  });
}
