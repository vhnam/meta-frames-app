import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';

import '../../testing/fakes.dart';

/// Opens Edit Camera the way a user does: Gear, then details, then Edit.
Future<GoRouter> _pumpEdit(
  WidgetTester tester,
  FakeCameraRepository cameras,
) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.gear);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraRepositoryProvider.overrideWithValue(cameras),
        rollRepositoryProvider.overrideWithValue(FakeRollRepository()),
        lensRepositoryProvider.overrideWithValue(
          FakeLensRepository([lens('l1')]),
        ),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  final id = cameras.cameraList.first.id;
  router.push(Routes.camera(id));
  await tester.pumpAndSettle();
  router.push(Routes.cameraEdit(id));
  await tester.pumpAndSettle();
  return router;
}

Finder _appBarTitle(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  testWidgets('the details screen has no activate or delete action', (
    tester,
  ) async {
    final router = await _pumpEdit(
      tester,
      FakeCameraRepository(cameraList: [camera('c1')]),
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Deactivate camera'), findsNothing);
    expect(find.text('Delete camera'), findsNothing);
  });

  testWidgets('New Camera has no activate or delete action', (tester) async {
    final router = await _pumpEdit(
      tester,
      FakeCameraRepository(cameraList: [camera('c1')]),
    );
    router.go(Routes.cameraNew);
    await tester.pumpAndSettle();
    expect(_appBarTitle('New Camera'), findsOneWidget);
    expect(find.text('Deactivate camera'), findsNothing);
    expect(find.text('Delete camera'), findsNothing);
  });

  testWidgets('deactivating keeps the form open with its typed text', (
    tester,
  ) async {
    final cameras = FakeCameraRepository(cameraList: [camera('c1')]);
    await _pumpEdit(tester, cameras);
    await tester.enterText(find.byType(TextFormField).first, 'Canon');
    await tester.tap(find.text('Deactivate camera'));
    await tester.pumpAndSettle();
    expect(cameras.calls, contains('setActive:c1:false'));
    expect(_appBarTitle('Edit Camera'), findsOneWidget);
    expect(find.text('Canon'), findsOneWidget);
  });

  testWidgets('an inactive camera offers Activate', (tester) async {
    final cameras = FakeCameraRepository(
      cameraList: [camera('c1', active: false)],
    );
    await _pumpEdit(tester, cameras);
    expect(find.text('Deactivate camera'), findsNothing);
    await tester.tap(find.text('Activate camera'));
    await tester.pumpAndSettle();
    expect(cameras.calls, contains('setActive:c1:true'));
  });

  testWidgets('a loaded camera cannot be deactivated', (tester) async {
    final cameras = FakeCameraRepository(
      cameraList: [camera('c1', loaded: true)],
    );
    await _pumpEdit(tester, cameras);
    await tester.tap(find.text('Deactivate camera'));
    await tester.pump();
    expect(
      find.text('Camera is loaded. Finish the roll first.'),
      findsOneWidget,
    );
    expect(cameras.calls, isEmpty);
  });

  testWidgets('cancelling the delete dialog keeps the camera', (tester) async {
    final cameras = FakeCameraRepository(cameraList: [camera('c1')]);
    await _pumpEdit(tester, cameras);
    await tester.tap(find.text('Delete camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cameras.calls, isEmpty);
    expect(_appBarTitle('Edit Camera'), findsOneWidget);
  });

  testWidgets('deleting returns to Gear, not the deleted camera', (
    tester,
  ) async {
    final cameras = FakeCameraRepository(cameraList: [camera('c1')]);
    final router = await _pumpEdit(tester, cameras);
    await tester.tap(find.text('Delete camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(cameras.calls, contains('delete:c1'));
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.gear);
    expect(router.canPop(), isFalse);
  });
}
