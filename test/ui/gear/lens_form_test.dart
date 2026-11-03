import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/fakes.dart';

/// Opens Edit Lens the way a user does: Gear, then details, then Edit.
Future<GoRouter> _pumpEdit(
  WidgetTester tester,
  FakeLensRepository lenses,
) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: Routes.gear);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        lensRepositoryProvider.overrideWithValue(lenses),
        cameraRepositoryProvider.overrideWithValue(FakeCameraRepository()),
        rollRepositoryProvider.overrideWithValue(FakeRollRepository()),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  final id = lenses.all.first.id;
  router.push(Routes.lens(id));
  await tester.pumpAndSettle();
  router.push(Routes.lensEdit(id));
  await tester.pumpAndSettle();
  return router;
}

Lens _builtIn(String id) => Lens.fromJson({
  'id': id,
  'focalLength': 35,
  'maxAperture': 2.8,
  'isBuiltIn': true,
  'isActive': true,
});

Finder _appBarTitle(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  testWidgets('the details screen has no activate or delete action', (
    tester,
  ) async {
    final router = await _pumpEdit(tester, FakeLensRepository([lens('l1')]));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Deactivate lens'), findsNothing);
    expect(find.text('Delete lens'), findsNothing);
  });

  testWidgets('New Lens has no activate or delete action', (tester) async {
    final router = await _pumpEdit(tester, FakeLensRepository([lens('l1')]));
    router.go(Routes.lensNew);
    await tester.pumpAndSettle();
    expect(_appBarTitle('New Lens'), findsOneWidget);
    expect(find.text('Deactivate lens'), findsNothing);
    expect(find.text('Delete lens'), findsNothing);
  });

  testWidgets('a built-in lens has no activate or delete action', (
    tester,
  ) async {
    await _pumpEdit(tester, FakeLensRepository([_builtIn('l1')]));
    expect(_appBarTitle('Edit Lens'), findsOneWidget);
    expect(find.text('Deactivate lens'), findsNothing);
    expect(find.text('Delete lens'), findsNothing);
  });

  testWidgets('deactivating keeps the form open with its typed text', (
    tester,
  ) async {
    final lenses = FakeLensRepository([lens('l1')]);
    await _pumpEdit(tester, lenses);
    await tester.enterText(find.byType(TextFormField).first, 'Canon');
    await tester.tap(find.text('Deactivate lens'));
    await tester.pumpAndSettle();
    expect(lenses.calls, contains('setActive:l1:false'));
    expect(_appBarTitle('Edit Lens'), findsOneWidget);
    expect(find.text('Canon'), findsOneWidget);
  });

  testWidgets('an inactive lens offers Activate', (tester) async {
    final lenses = FakeLensRepository([lens('l1', active: false)]);
    await _pumpEdit(tester, lenses);
    expect(find.text('Deactivate lens'), findsNothing);
    await tester.tap(find.text('Activate lens'));
    await tester.pumpAndSettle();
    expect(lenses.calls, contains('setActive:l1:true'));
  });

  testWidgets('cancelling the delete dialog keeps the lens', (tester) async {
    final lenses = FakeLensRepository([lens('l1')]);
    await _pumpEdit(tester, lenses);
    await tester.tap(find.text('Delete lens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(lenses.calls, isEmpty);
    expect(_appBarTitle('Edit Lens'), findsOneWidget);
  });

  testWidgets('deleting returns to Gear, not the deleted lens', (tester) async {
    final lenses = FakeLensRepository([lens('l1')]);
    final router = await _pumpEdit(tester, lenses);
    await tester.tap(find.text('Delete lens'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(lenses.calls, contains('delete:l1'));
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.gear);
    expect(router.canPop(), isFalse);
  });
}
