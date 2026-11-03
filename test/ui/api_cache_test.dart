import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_filter.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/gear/view_models/gear_actions.dart';
import 'package:meta_frames/ui/scans/view_models/scan_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';

class _FlakyCameras extends FakeCameraRepository {
  bool fail = true;

  @override
  Future<List<Camera>> cameras() {
    if (fail) {
      listCalls++;
      return Future.error(StateError('offline'));
    }
    return super.cameras();
  }
}

class _CountingScans extends FakeScanRepository {
  int compareCalls = 0;

  @override
  Future<FrameComparison> compare(String processingId, int n) async {
    compareCalls++;
    return FrameComparison.fromJson({'frameNumber': n});
  }
}

class _App {
  _App(this.router, this.container, this.rolls, this.cameras, this.lenses);
  final GoRouter router;
  final ProviderContainer container;
  final FakeRollRepository rolls;
  final FakeCameraRepository cameras;
  final FakeLensRepository lenses;
}

Future<_App> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final rolls = FakeRollRepository([roll('r1')]);
  final cameras = FakeCameraRepository(cameraList: [camera('c1')]);
  final lenses = FakeLensRepository([lens('l1')]);
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      sessionStoreProvider.overrideWithValue(SessionStore('token')),
      rollRepositoryProvider.overrideWithValue(rolls),
      cameraRepositoryProvider.overrideWithValue(cameras),
      lensRepositoryProvider.overrideWithValue(lenses),
      filmStockRepositoryProvider.overrideWithValue(
        FakeFilmStockRepository([stock('s1')]),
      ),
      processingRepositoryProvider.overrideWithValue(
        FakeProcessingRepository(),
      ),
      labRepositoryProvider.overrideWithValue(FakeLabRepository()),
      scannerRepositoryProvider.overrideWithValue(FakeScannerRepository()),
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: Routes.home);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _App(router, container, rolls, cameras, lenses);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching bottom tabs does not call the API again', (
    tester,
  ) async {
    final app = await _pumpApp(tester);
    await _tap(tester, 'Rolls');
    await _tap(tester, 'More');
    final rollCalls = app.rolls.listCalls;
    final cameraCalls = app.cameras.listCalls;

    await _tap(tester, 'Home');
    await _tap(tester, 'Rolls');
    await _tap(tester, 'Home');

    expect(app.rolls.listCalls, rollCalls);
    expect(app.cameras.listCalls, cameraCalls);
  });

  testWidgets('Gear segments and reopening Gear do not call the API again', (
    tester,
  ) async {
    final app = await _pumpApp(tester);
    app.router.push(Routes.gear);
    await tester.pumpAndSettle();
    await _tap(tester, 'Lenses');
    final cameraCalls = app.cameras.listCalls;
    final lensCalls = app.lenses.listCalls;

    await _tap(tester, 'Cameras');
    await _tap(tester, 'Lenses');
    app.router.pop();
    await tester.pumpAndSettle();
    app.router.push(Routes.gear);
    await tester.pumpAndSettle();
    await _tap(tester, 'Lenses');

    expect(app.cameras.listCalls, cameraCalls);
    expect(app.lenses.listCalls, lensCalls);
  });

  testWidgets('a write refreshes the list on screen', (tester) async {
    final app = await _pumpApp(tester);
    final before = app.cameras.listCalls;

    await app.container
        .read(cameraActionsProvider)
        .setActive(camera('c1'), false);
    await tester.pumpAndSettle();

    expect(app.cameras.listCalls, before + 1);
  });

  testWidgets('a write waits for a hidden tab to open again', (tester) async {
    final app = await _pumpApp(tester);
    await _tap(tester, 'Rolls');
    await _tap(tester, 'More');
    final before = app.rolls.listCalls;

    app.container.invalidate(rollsProvider(RollFilter.empty));
    await tester.pumpAndSettle();
    expect(app.rolls.listCalls, before);

    await _tap(tester, 'Rolls');
    expect(app.rolls.listCalls, before + 1);
  });

  group('without a screen', () {
    ProviderContainer containerWith(FakeCameraRepository cameras) {
      final container = ProviderContainer(
        overrides: [cameraRepositoryProvider.overrideWithValue(cameras)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('an answer stays after the last listener leaves', () async {
      final cameras = FakeCameraRepository();
      final container = containerWith(cameras);
      final sub = container.listen(camerasProvider, (_, _) {});
      await container.read(camerasProvider.future);
      sub.close();
      await settle();

      await container.read(camerasProvider.future);

      expect(cameras.listCalls, 1);
    });

    test('an invalidated list waits for the next reader', () async {
      final cameras = FakeCameraRepository();
      final container = containerWith(cameras);
      final sub = container.listen(camerasProvider, (_, _) {});
      await container.read(camerasProvider.future);
      sub.close();
      await settle();

      container.invalidate(camerasProvider);
      await settle();
      expect(cameras.listCalls, 1);

      await container.read(camerasProvider.future);
      expect(cameras.listCalls, 2);
    });

    test('lens details reuse the cached camera list', () async {
      final cameras = FakeCameraRepository(
        cameraList: [camera('c1')],
        linked: {
          'c1': [lens('l1')],
        },
      );
      final container = containerWith(cameras);
      final sub = container.listen(camerasProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(camerasProvider.future);

      final linked = await container.read(lensCamerasProvider('l1').future);

      expect(linked.map((c) => c.id), ['c1']);
      expect(cameras.listCalls, 1);
    });

    test('returning to a frame reuses it until scans are imported', () async {
      final scans = _CountingScans();
      final container = ProviderContainer(
        overrides: [scanRepositoryProvider.overrideWithValue(scans)],
      );
      addTearDown(container.dispose);
      Future<void> view(int frame) async {
        final sub = container.listen(compareProvider(('p1', frame)), (_, _) {});
        await container.read(compareProvider(('p1', frame)).future);
        sub.close();
        await settle();
      }

      await view(1);
      await view(2);
      await view(1);
      expect(scans.compareCalls, 2);

      container.read(scanActionsProvider).importsFinished('p1');
      await settle();
      expect(scans.compareCalls, 2);

      await view(1);
      expect(scans.compareCalls, 3);
    });

    test('a failed call is not kept', () async {
      final cameras = _FlakyCameras();
      final container = containerWith(cameras);
      final sub = container.listen(camerasProvider, (_, _) {});
      await expectLater(
        container.read(camerasProvider.future),
        throwsStateError,
      );
      sub.close();
      await settle();
      cameras.fail = false;

      await expectLater(container.read(camerasProvider.future), completes);
    });
  });
}
