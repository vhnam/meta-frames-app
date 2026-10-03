import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';

/// Pumps the real router against fake repositories, starting at [location].
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  String location = Routes.home,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        rollRepositoryProvider.overrideWithValue(
          FakeRollRepository([roll('r1')]),
        ),
        cameraRepositoryProvider.overrideWithValue(
          FakeCameraRepository(
            cameraList: [camera('c1')],
            linked: {
              'c1': [lens('l1')],
            },
          ),
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
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('Routes', () {
    test('builds paths with their ids', () {
      expect(Routes.camera('c1'), '/cameras/c1');
      expect(Routes.cameraEdit('c1'), '/cameras/c1/edit');
      expect(Routes.frame('r1', 3), '/rolls/r1/frames/3');
      expect(Routes.compare('p1', 4), '/processing/p1/frames/4/compare');
      expect(
        Routes.scanViewer('p1', Scanner.frontier, 2),
        '/processing/p1/scans/frontier/2',
      );
    });

    test('optional parts only appear when asked for', () {
      expect(Routes.rollNew(), '/rolls/new');
      expect(Routes.rollNew(stockId: 's1'), '/rolls/new?stockId=s1');
      expect(Routes.rollSend('r1'), '/rolls/r1/send');
      expect(Routes.rollSend('r1', resend: true), '/rolls/r1/send?resend=true');
    });
  });

  group('tabs', () {
    testWidgets('opens on Home with the tab bar', (tester) async {
      await pumpRouter(tester);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('/ redirects to Home', (tester) async {
      final router = await pumpRouter(tester, location: '/');
      expect(_location(router), Routes.home);
    });

    testWidgets('switching tabs changes the location and keeps each tab', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      await tester.tap(find.text('Gear'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.gear);
      expect(find.text('Nikon c1'), findsOneWidget);

      await tester.tap(find.text('Rolls').last);
      await tester.pumpAndSettle();
      expect(_location(router), Routes.rolls);
      expect(find.text('Kodak Gold'), findsOneWidget);
    });
  });

  group('screens over the tab bar', () {
    testWidgets('a detail screen can be opened directly', (tester) async {
      final router = await pumpRouter(tester, location: Routes.camera('c1'));

      expect(_location(router), '/cameras/c1');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Nikon c1'), findsWidgets);
    });

    testWidgets('/cameras/new is the form, not a camera called "new"', (
      tester,
    ) async {
      await pumpRouter(tester, location: Routes.cameraNew);
      expect(find.text('New Camera'), findsOneWidget);
    });

    testWidgets('an edit route loads the object by id', (tester) async {
      await pumpRouter(tester, location: Routes.cameraEdit('c1'));

      expect(find.text('Edit Camera'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nikon'), findsOneWidget);
    });

    testWidgets('a load route waits for the data, then shows the screen', (
      tester,
    ) async {
      await pumpRouter(tester, location: Routes.rollLoad('r1'));
      expect(find.text('Load roll'), findsWidgets);
      expect(find.text('Kodak Gold · 135'), findsOneWidget);
    });

    testWidgets(
      'a route with a failing load shows the error with a back button',
      (tester) async {
        await pumpRouter(tester, location: Routes.cameraEdit('missing'));
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('No element'), findsOneWidget);
      },
    );
  });

  group('navigation from a tab', () {
    testWidgets('push opens a screen over the tab bar and back returns to it', (
      tester,
    ) async {
      final router = await pumpRouter(tester, location: Routes.rolls);

      await tester.tap(find.text('Kodak Gold'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.roll('r1'));
      expect(find.byType(NavigationBar), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), Routes.rolls);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a pushed screen can return a result', (tester) async {
      final router = await pumpRouter(tester);
      String? result;

      final future = router.push<String>(Routes.search);
      await tester.pumpAndSettle();
      future.then((v) => result = v);
      router.pop('done');
      await tester.pumpAndSettle();

      expect(result, 'done');
    });

    testWidgets('secondary screens open over the tab bar', (tester) async {
      final router = await pumpRouter(tester);
      router.push(Routes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('SERVER URL'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('closing screens', () {
    testWidgets('a screen opened from a link goes Home when closed', (
      tester,
    ) async {
      final router = await pumpRouter(tester, location: Routes.settings);
      expect(router.canPop(), isFalse);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(_location(router), Routes.home);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('a screen pushed from a tab returns to it when closed', (
      tester,
    ) async {
      final router = await pumpRouter(tester, location: Routes.rolls);
      router.push(Routes.settings);
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(_location(router), Routes.rolls);
    });
  });

  group('More tab', () {
    testWidgets('lists every secondary screen', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      for (final label in [
        'Search rolls',
        'Film stocks',
        'Expiry',
        'Negatives at lab',
        'Labs',
        'Settings',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('each entry opens its screen over the tab bar', (tester) async {
      final router = await pumpRouter(tester, location: Routes.more);
      final entries = {
        'Search rolls': Routes.search,
        'Film stocks': Routes.film,
        'Expiry': Routes.expiry,
        'Negatives at lab': Routes.negativesAtLab,
        'Labs': Routes.labs,
        'Settings': Routes.settings,
      };

      for (final e in entries.entries) {
        await tester.tap(find.text(e.key));
        await tester.pumpAndSettle();
        expect(_location(router), e.value, reason: e.key);
        expect(find.byType(NavigationBar), findsNothing);

        router.pop();
        await tester.pumpAndSettle();
        expect(_location(router), Routes.more);
      }
    });
  });
}
