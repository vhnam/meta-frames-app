import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/fakes.dart';

/// A camera holding roll [rollId].
Camera _loaded(String id, String rollId) => Camera.fromJson({
  'id': id,
  'brand': 'Nikon',
  'model': id,
  'mount': 'F',
  'hasFixedLens': false,
  'isActive': true,
  'loadedRoll': {
    'rollId': rollId,
    'stockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'shotIso': 400,
    'startedAt': '2026-11-01',
    'daysLoaded': 6,
  },
});

void main() {
  late FakeRollRepository rolls;

  Future<GoRouter> pump(WidgetTester tester, List<Camera> cams) async {
    tester.view
      ..physicalSize = const Size(400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(SessionStore('token')),
          rollRepositoryProvider.overrideWithValue(rolls),
          cameraRepositoryProvider.overrideWithValue(
            FakeCameraRepository(cameraList: cams),
          ),
          lensRepositoryProvider.overrideWithValue(FakeLensRepository()),
          filmStockRepositoryProvider.overrideWithValue(
            FakeFilmStockRepository([stock('s1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.last.matchedLocation;

  setUp(() {
    rolls = FakeRollRepository([
      roll('ra', status: 'in_camera'),
      roll('rb', status: 'in_camera'),
    ]);
  });

  testWidgets('each camera finishes its own roll', (tester) async {
    await pump(tester, [_loaded('fm2', 'ra'), _loaded('f3', 'rb')]);

    await tester.tap(find.text('Finish').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();

    expect(rolls.calls, ['finish:ra']);
  });

  testWidgets('an empty camera loads into that camera', (tester) async {
    final router = await pump(tester, [_loaded('fm2', 'ra'), camera('xa')]);

    await tester.tap(find.widgetWithText(FilledButton, 'Load'));
    await tester.pumpAndSettle();

    expect(location(router), Routes.cameraLoadRoll('xa'));
  });
}
