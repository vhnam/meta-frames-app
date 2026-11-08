import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/view_models/frame_notes.dart';
import 'package:meta_frames/ui/shooting/view_models/shooting_view_model.dart';

import '../../testing/fakes.dart';

/// Serves a roll detail with the frames the fake server holds for it.
class _Rolls extends FakeRollRepository {
  _Rolls(super.all);

  /// Frames with scans but no notes, by roll id.
  final scanned = <String, List<int>>{};

  @override
  Future<RollDetail> roll(String id) async {
    final numbers = {
      for (final k in frameNotes.keys)
        if (k.$1 == id) k.$2,
      ...?scanned[id],
    };
    return RollDetail.fromJson({
      ..._detail(id),
      'frames': [
        for (final n in numbers)
          {
            'id': '$id-$n',
            'number': n,
            'notes': frameNotes[(id, n)],
            'scans': scanned[id]?.contains(n) ?? false
                ? [
                    {'id': 's$n', 'frameNumber': n, 'scanner': 'noritsu'},
                  ]
                : [],
          },
      ],
    });
  }
}

Map<String, dynamic> _detail(String id) => {
  'roll': {
    'id': id,
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': 'in_camera',
  },
  'stock': {
    'id': 's1',
    'brand': 'Kodak',
    'name': 'Gold',
    'type': 'color',
    'boxIso': '200',
    'process': 'C-41',
    'packaging': 'factory',
  },
  'totals': {
    'rollPrice': 0,
    'processingPrice': 0,
    'total': 0,
    'incomplete': false,
  },
};

void main() {
  late _Rolls rolls;

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

  setUp(() => rolls = _Rolls([]));

  test('every camera holding a roll is listed, active or not', () async {
    final c = containerWith(
      cams: [
        camera('fm2', loaded: true),
        camera('xa', loaded: true),
        camera('empty'),
        // Older data can leave a roll in a camera that was since retired. It
        // must stay findable so the roll can be noted and finished.
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

  test(
    'a loaded roll lists its noted frames in order, not scan-only ones',
    () async {
      final c = containerWith();
      rolls.scanned['r0'] = [2];
      final actions = c.read(notesActionsProvider);
      await actions.save((rollId: 'r0', frame: 12), 'Bridge');
      await actions.save((rollId: 'r0', frame: 3), 'Market');
      await actions.save((rollId: 'r0', frame: 5), 'cleared later');
      await actions.save((rollId: 'r0', frame: 5), '');

      final provider = notedFramesProvider('r0');
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await c.read(rollDetailProvider('r0').future);

      expect(c.read(provider).requireValue.map((f) => f.number), [3, 12]);

      // A new note shows without a manual refresh.
      await actions.save((rollId: 'r0', frame: 1), 'Leader');
      await c.read(rollDetailProvider('r0').future);
      expect(c.read(provider).requireValue.map((f) => f.number), [1, 3, 12]);
    },
  );

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
