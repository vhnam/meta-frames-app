import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/gear/widgets/gear_tab.dart';
import 'package:meta_frames/ui/home/widgets/home_tab.dart';
import 'package:meta_frames/ui/rolls/widgets/load_roll.dart';
import 'package:meta_frames/ui/rolls/widgets/rolls_tab.dart';

import '../testing/fakes.dart';

/// Builds [child] with fake repositories instead of a server.
Widget app(
  Widget child, {
  FakeRollRepository? rolls,
  FakeCameraRepository? cameras,
}) {
  return ProviderScope(
    overrides: [
      rollRepositoryProvider.overrideWithValue(rolls ?? FakeRollRepository()),
      cameraRepositoryProvider.overrideWithValue(
        cameras ?? FakeCameraRepository(),
      ),
      lensRepositoryProvider.overrideWithValue(
        FakeLensRepository([lens('l1')]),
      ),
      filmStockRepositoryProvider.overrideWithValue(
        FakeFilmStockRepository([stock('s1')]),
      ),
      processingRepositoryProvider.overrideWithValue(
        FakeProcessingRepository(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('rolls tab lists rolls and narrows them with a status chip', (
    tester,
  ) async {
    final rolls = FakeRollRepository([
      roll('a'),
      roll('b', status: 'in_camera'),
    ]);
    await tester.pumpWidget(app(const RollsTab(), rolls: rolls));
    await tester.pumpAndSettle();

    expect(find.text('Kodak Gold'), findsNWidgets(2));
    expect(find.text('ALL 2'), findsOneWidget);
    expect(find.text('IN CAMERA 1'), findsOneWidget);

    await tester.tap(find.text('IN CAMERA 1'));
    await tester.pumpAndSettle();
    expect(find.text('Kodak Gold'), findsOneWidget);
  });

  testWidgets('rolls tab filter sheet opens and clears', (tester) async {
    await tester.pumpWidget(
      app(const RollsTab(), rolls: FakeRollRepository([roll('a')])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.text('Started from'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all'), findsNothing);
  });

  testWidgets('load roll screen shows the roll, lenses and enables Load', (
    tester,
  ) async {
    final cameras = FakeCameraRepository(
      cameraList: [camera('c1')],
      linked: {
        'c1': [lens('l1')],
      },
    );
    await tester.pumpWidget(
      app(
        LoadRollScreen(camera: camera('c1'), roll: roll('r1')),
        cameras: cameras,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nikon c1'), findsOneWidget);
    expect(find.text('Kodak Gold · 135'), findsOneWidget);
    expect(find.text('Nikon l1 50mm f/1.8'), findsOneWidget);
    final load = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Load'),
    );
    expect(load.onPressed, isNotNull);
  });

  testWidgets(
    'load roll screen cannot submit before a roll and camera are chosen',
    (tester) async {
      await tester.pumpWidget(app(const LoadRollScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Select a camera first.'), findsOneWidget);
      final load = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Load'),
      );
      expect(load.onPressed, isNull);
    },
  );

  testWidgets('gear tab splits active and inactive cameras', (tester) async {
    final cameras = FakeCameraRepository(
      cameraList: [camera('c1'), camera('old', active: false)],
    );
    await tester.pumpWidget(app(const GearTab(), cameras: cameras));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE · 1'), findsOneWidget);
    expect(find.textContaining('INACTIVE · 1'), findsOneWidget);
    expect(find.text('+ Add'), findsOneWidget);
  });

  testWidgets('gear tab offers + Camera when there is none', (tester) async {
    await tester.pumpWidget(app(const GearTab()));
    await tester.pumpAndSettle();

    expect(find.text('+ Camera'), findsOneWidget);
    expect(find.text('No cameras yet'), findsOneWidget);
  });

  testWidgets('home shows counters from the data', (tester) async {
    final cameras = FakeCameraRepository(
      cameraList: [camera('c1', loaded: true)],
    );
    final rolls = FakeRollRepository([roll('a', status: 'done_shooting')]);
    await tester.pumpWidget(
      app(const HomeTab(), rolls: rolls, cameras: cameras),
    );
    await tester.pumpAndSettle();

    // The counter strip uses 26pt numbers; section numbers are smaller.
    Finder counter(String n) => find.byWidgetPredicate(
      (w) => w is Text && w.data == n && w.style?.fontSize == 26,
    );
    expect(find.text('LOADED'), findsOneWidget);
    expect(counter('01'), findsNWidgets(2)); // Loaded and Ready
    expect(counter('00'), findsNWidgets(2)); // At lab and Expiring
  });
}
