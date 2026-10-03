import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/home/view_models/home_view_model.dart';

import '../../testing/fakes.dart';

void main() {
  ProviderContainer containerWith({
    List<dynamic> cams = const [],
    List<dynamic> rolls = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        cameraRepositoryProvider.overrideWithValue(
          FakeCameraRepository(cameraList: [...cams]),
        ),
        rollRepositoryProvider.overrideWithValue(
          FakeRollRepository([...rolls]),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('only active cameras with a roll count as loaded', () async {
    final c = containerWith(
      cams: [
        camera('loaded', loaded: true),
        camera('empty'),
        camera('retired', active: false, loaded: true),
      ],
    );
    final sub = c.listen(loadedCamerasProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(camerasProvider.future);

    expect(c.read(loadedCamerasProvider).requireValue.map((x) => x.id), [
      'loaded',
    ]);
    expect(c.read(homeCountersProvider).loaded, 1);
  });

  test('finished rolls are the ones ready for the lab', () async {
    final c = containerWith(
      rolls: [
        roll('a', status: 'done_shooting'),
        roll('b', status: 'in_camera'),
      ],
    );
    final sub = c.listen(readyRollsProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(rollsProvider(RollFilter.empty).future);

    expect(c.read(readyRollsProvider).requireValue.map((r) => r.id), ['a']);
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
