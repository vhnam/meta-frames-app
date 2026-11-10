import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/session_store.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/labs/widgets/lab_detail.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/rolls/widgets/expiry_screen.dart';
import 'package:meta_frames/ui/rolls/widgets/load_roll.dart';
import 'package:meta_frames/ui/shooting/widgets/shooting_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';

/// Pumps the real router against fake repositories, starting at [location].
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  String location = Routes.shooting,
  FakeProcessingRepository? processing,
  FakeScannerRepository? scanners,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(SessionStore('token')),
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
          processing ?? FakeProcessingRepository(),
        ),
        labRepositoryProvider.overrideWithValue(
          FakeLabRepository([lab('b1', 'Foto Lab')]),
        ),
        scannerRepositoryProvider.overrideWithValue(
          scanners ?? FakeScannerRepository(),
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
      expect(Routes.lab('b1'), '/labs/b1');
      expect(Routes.frame('r1', 3), '/rolls/r1/frames/3');
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

  group('labs', () {
    testWidgets('a lab row opens the lab page', (tester) async {
      final router = await pumpRouter(tester, location: Routes.labs);
      await tester.tap(find.text('Foto Lab'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.lab('b1'));
      expect(find.byType(LabDetailScreen), findsOneWidget);
    });
  });

  group('removed import and compare screens', () {
    // The jobs exist, so these paths would have opened a screen before M-13.
    for (final path in [
      '/processing/j1/import',
      '/processing/j1/frames/4/compare',
    ]) {
      testWidgets('$path opens the error page', (tester) async {
        final processing = FakeProcessingRepository()
          ..jobs['j1'] = Processing.fromJson({
            'id': 'j1',
            'rollId': 'r1',
            'type': 'develop_scan',
            'process': 'C-41',
            'sentAt': '2026-01-01',
            'isOpen': true,
          });
        final router = await pumpRouter(
          tester,
          location: path,
          processing: processing,
        );
        expect(router.routerDelegate.currentConfiguration.isError, isTrue);
      });
    }
  });

  group('removed gear, stock and lab admin screens', () {
    // The camera, lens and stock exist, so these paths opened a form before
    // M-14.
    for (final path in [
      '/cameras/c1/edit',
      '/cameras/c1/lenses',
      '/lenses/l1/edit',
      '/stocks/s1/edit',
    ]) {
      testWidgets('$path opens the error page, not a form', (tester) async {
        final router = await pumpRouter(tester, location: path);
        expect(router.routerDelegate.currentConfiguration.isError, isTrue);
        expect(find.byType(TextFormField), findsNothing);
      });
    }

    testWidgets('the camera itself still opens, read-only', (tester) async {
      await pumpRouter(tester, location: Routes.camera('c1'));
      expect(find.text('Nikon c1'), findsWidgets);
    });
  });

  group('tabs', () {
    testWidgets('opens on Shooting with the tab bar', (tester) async {
      await pumpRouter(tester);
      expect(find.byType(ShootingTab), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('/ redirects to Shooting', (tester) async {
      final router = await pumpRouter(tester, location: '/');
      expect(_location(router), Routes.shooting);
    });

    testWidgets('the old Home location redirects to Shooting', (tester) async {
      final router = await pumpRouter(tester, location: Routes.home);
      expect(_location(router), Routes.shooting);
      expect(find.byType(ShootingTab), findsOneWidget);
    });

    testWidgets('switching tabs changes the location and keeps each tab', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.more);
      expect(find.text('Film stocks'), findsOneWidget);

      await tester.tap(find.text('Rolls').last);
      await tester.pumpAndSettle();
      expect(_location(router), Routes.rolls);
      expect(find.text('Kodak Gold'), findsOneWidget);
    });
  });

  group('retired routes', () {
    testWidgets(
      'the old processing edit link opens no form and writes nothing',
      (tester) async {
        // A job that exists, so only the missing route keeps the form closed.
        final processing = FakeProcessingRepository()
          ..jobs['p1'] = Processing.fromJson({
            'id': 'p1',
            'rollId': 'r1',
            'type': ProcessingType.develop.wire,
            'process': Process.c41.wire,
            'sentAt': '2026-01-01',
            'isOpen': true,
          });
        final router = await pumpRouter(
          tester,
          location: '/processing/p1/edit',
          processing: processing,
        );
        expect(router.routerDelegate.currentConfiguration.isError, isTrue);
        expect(find.byType(TextField), findsNothing);
        expect(processing.sent, isEmpty);
        expect(processing.deleted, isEmpty);
      },
    );

    testWidgets('old scanner and order links open no form and write nothing', (
      tester,
    ) async {
      // A scanner that exists, so only the missing routes keep the forms closed.
      final scanners = FakeScannerRepository([scanner('s1', 'Noritsu')]);
      for (final link in [
        '/scanners',
        '/scanners/new',
        '/scanners/s1',
        '/orders',
        '/orders/new',
        '/orders/o1',
        '/orders/o1/edit',
        '/orders/o1/add-roll',
      ]) {
        final router = await pumpRouter(
          tester,
          location: link,
          scanners: scanners,
        );
        expect(
          router.routerDelegate.currentConfiguration.isError,
          isTrue,
          reason: link,
        );
        expect(find.byType(TextField), findsNothing, reason: link);
      }
    });
  });

  group('screens over the tab bar', () {
    testWidgets('the Expiry screen stays reachable by link', (tester) async {
      await pumpRouter(tester, location: Routes.expiry);
      expect(find.byType(ExpiryScreen), findsOneWidget);
    });

    testWidgets('load opens with neither camera nor roll picked', (
      tester,
    ) async {
      await pumpRouter(tester, location: Routes.load);
      final screen = tester.widget<LoadRollScreen>(find.byType(LoadRollScreen));
      expect(screen.camera, isNull);
      expect(screen.roll, isNull);
    });

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
        await pumpRouter(tester, location: Routes.cameraLoadRoll('missing'));
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

      final future = router.push<String>(Routes.settings);
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
    testWidgets('a screen opened from a link goes to Shooting when closed', (
      tester,
    ) async {
      final router = await pumpRouter(tester, location: Routes.settings);
      expect(router.canPop(), isFalse);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(_location(router), Routes.shooting);
      expect(find.byType(ShootingTab), findsOneWidget);
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
        'Gear',
        'Film stocks',
        'Negatives at lab',
        'Labs',
        'Settings',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 200);
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('each entry opens its screen over the tab bar', (tester) async {
      final router = await pumpRouter(tester, location: Routes.more);
      final entries = {
        'Gear': Routes.gear,
        'Film stocks': Routes.film,
        'Negatives at lab': Routes.negativesAtLab,
        'Labs': Routes.labs,
        'Settings': Routes.settings,
      };

      for (final e in entries.entries) {
        // A lazy list builds only what is near the screen.
        await tester.scrollUntilVisible(find.text(e.key), 200);
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

  group('Gear', () {
    testWidgets('Back returns to More', (tester) async {
      final router = await pumpRouter(tester, location: Routes.more);
      await tester.tap(find.text('Gear'));
      await tester.pumpAndSettle();
      expect(find.text('Nikon c1'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.more);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('opened from a link, Back goes to Shooting', (tester) async {
      final router = await pumpRouter(tester, location: Routes.gear);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.shooting);
    });
  });

  group('system navigation bar', () {
    const inset = 48.0;

    void useBar(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(bottom: inset * 3);
      tester.view.viewPadding = const FakeViewPadding(bottom: inset * 3);
      addTearDown(tester.view.reset);
    }

    testWidgets('a screen over the tab bar stays clear of it', (tester) async {
      useBar(tester);
      await pumpRouter(tester, location: Routes.rollNew());

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final save = tester.getBottomRight(find.byType(FilledButton)).dy;
      expect(save, lessThanOrEqualTo(500 - inset));
    });

    testWidgets('a pick sheet stays clear of it', (tester) async {
      useBar(tester);
      await pumpRouter(tester);
      final context = tester.element(find.byType(NavigationBar));

      pickOne<String>(
        context,
        title: 'Stock',
        items: const ['a'],
        label: (s) => s,
        footer: const Text('footer'),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getBottomRight(find.text('footer')).dy,
        lessThanOrEqualTo(500 - inset),
      );
    });
  });
}
