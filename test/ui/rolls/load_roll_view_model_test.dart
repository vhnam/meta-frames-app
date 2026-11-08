import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/utils.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/load_roll_view_model.dart';

import '../../testing/fakes.dart';

void main() {
  late FakeRollRepository rolls;
  late FakeCameraRepository cameras;
  late FakeLensRepository lenses;
  late ProviderContainer container;

  setUp(() {
    rolls = FakeRollRepository([
      roll('late', expiry: {'year': 2030}),
      roll('soon', expiry: {'year': 2020, 'month': 1}),
      roll('none'),
    ]);
    cameras = FakeCameraRepository(
      cameraList: [
        camera('free'),
        camera('busy', loaded: true),
        camera('off', active: false),
      ],
      linked: {
        'free': [lens('l1')],
      },
    );
    lenses = FakeLensRepository([
      lens('l1'),
      lens('l2'),
      lens('l3', active: false),
    ]);
    container = ProviderContainer(
      overrides: [
        rollRepositoryProvider.overrideWithValue(rolls),
        cameraRepositoryProvider.overrideWithValue(cameras),
        lensRepositoryProvider.overrideWithValue(lenses),
      ],
    );
    addTearDown(container.dispose);
  });

  LoadRollArgs args({bool withCamera = false}) =>
      (camera: withCamera ? camera('free') : null, roll: roll('r1'));

  test(
    'rolls to load are listed soonest expiry first, no expiry last',
    () async {
      final vm = container.read(loadRollViewModelProvider(args()).notifier);
      final ids = (await vm.inStockRolls()).map((r) => r.id).toList();
      expect(ids, ['soon', 'late', 'none']);
    },
  );

  test('only active, empty cameras can be chosen', () async {
    final vm = container.read(loadRollViewModelProvider(args()).notifier);
    expect((await vm.emptyCameras()).map((c) => c.id), ['free']);
  });

  test(
    'choosing a camera loads its linked lenses and resets selection',
    () async {
      final provider = loadRollViewModelProvider(args());
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final vm = container.read(provider.notifier);

      vm.selectCamera(camera('free'));
      expect(container.read(provider).suggested, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).suggested!.map((l) => l.id), ['l1']);

      vm.toggleLens('l1', true);
      expect(container.read(provider).lensIds, {'l1'});
      vm.selectCamera(camera('free'));
      expect(container.read(provider).lensIds, isEmpty);
    },
  );

  test('adapted lenses exclude the ones already offered', () async {
    final provider = loadRollViewModelProvider(args(withCamera: true));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    final others = await container.read(provider.notifier).otherLenses();
    expect(others.map((l) => l.id), ['l2']);
  });

  test('submit sends the chosen lenses', () async {
    final provider = loadRollViewModelProvider(args(withCamera: true));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    final vm = container.read(provider.notifier)..toggleLens('l1', true);

    await vm.submit(shotIso: 800);

    expect(rolls.calls, ['load:r1']);
    expect(rolls.lastLoad!.toJson(), {
      'cameraId': 'free',
      'startedAt': rolls.lastLoad!.toJson()['startedAt'],
      'shotIso': 800,
      'lensIds': ['l1'],
    });
  });

  test('a fixed-lens camera never sends lens ids', () async {
    final provider = loadRollViewModelProvider((
      camera: camera('fixed', fixedLens: true),
      roll: roll('r1'),
    ));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final vm = container.read(provider.notifier)..toggleLens('l1', true);

    await vm.submit();

    expect(rolls.lastLoad!.toJson().containsKey('lensIds'), isFalse);
  });

  test('camera and roll are enough: today, box speed, no lenses', () async {
    final provider = loadRollViewModelProvider(args(withCamera: true));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).canSubmit, isTrue);

    await container.read(provider.notifier).submit();

    expect(rolls.lastLoad!.toJson(), {
      'cameraId': 'free',
      'startedAt': ymd(DateTime.now()),
    });
  });

  group('parseShotIso', () {
    test('empty means box speed', () {
      expect(parseShotIso(''), isNull);
      expect(parseShotIso('  '), isNull);
      expect(parseShotIso(' 800 '), 800);
    });

    test('a typo is refused, never loaded as box speed', () {
      for (final bad in ['0', '-400', '8OO', '400.5', '1/3']) {
        expect(() => parseShotIso(bad), throwsFormatException, reason: bad);
      }
    });
  });

  test('the roll picker flags what the server reports as expiring', () async {
    rolls.expiryView = ExpiryView.fromJson({
      'expiring': [
        {
          'roll': {
            'id': 'soon',
            'filmStockId': 's1',
            'stockBrand': 'Kodak',
            'stockName': 'Gold',
            'format': 135,
            'exposures': 36,
            'status': 'in_stock',
          },
          'expiresOn': '2020-01-31',
          'expired': true,
        },
      ],
      'noExpiry': [],
    });
    final vm = container.read(loadRollViewModelProvider(args()).notifier);
    expect(await vm.expiringRollIds(), {'soon'});
  });
}
