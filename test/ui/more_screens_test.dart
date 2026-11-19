import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/core/widgets/cards.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/film/widgets/film_tab.dart';
import 'package:meta_frames/ui/labs/widgets/labs_screen.dart';
import 'package:meta_frames/ui/labs/widgets/negatives_at_lab.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:meta_frames/ui/rolls/widgets/expiry_screen.dart';
import 'package:meta_frames/ui/rolls/widgets/roll_card.dart';
import 'package:meta_frames/data/local/local_store.dart';
import 'package:meta_frames/data/sync/pending_op.dart';
import 'package:meta_frames/data/sync/sync_engine.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/more/widgets/more_tab.dart';
import 'package:meta_frames/ui/sync/view_models/sync_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';
import '../testing/local.dart';

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  FakeRollRepository? rolls,
  FakeLabRepository? labs,
  FakeProcessingRepository? processing,
  FakeFilmStockRepository? stocks,
  FakeScannerRepository? scanners,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        rollRepositoryProvider.overrideWithValue(rolls ?? FakeRollRepository()),
        labRepositoryProvider.overrideWithValue(labs ?? FakeLabRepository()),
        scannerRepositoryProvider.overrideWithValue(
          scanners ?? FakeScannerRepository(),
        ),
        processingRepositoryProvider.overrideWithValue(
          processing ?? FakeProcessingRepository(),
        ),
        filmStockRepositoryProvider.overrideWithValue(
          stocks ?? FakeFilmStockRepository([stock('s1')]),
        ),
        cameraRepositoryProvider.overrideWithValue(FakeCameraRepository()),
        lensRepositoryProvider.overrideWithValue(FakeLensRepository()),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

NegativesAtLabItem atLab({int days = 3}) => NegativesAtLabItem.fromJson({
  'processingId': 'p1',
  'rollId': 'r1',
  'labName': 'Foto Lab',
  'type': 'develop_scan',
  'sentAt': '2026-01-01',
  'daysSinceSent': days,
  'stockName': 'Gold',
});

class _MoreStore implements LocalStore {
  @override
  final key = const PartitionKey(server, 'u1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<PendingOp> _pendingChange(OpState state) {
  final timestamp = DateTime.utc(2026);
  return [
    PendingOp(
      seq: 1,
      opId: 'queued',
      kind: OpKind.rollNotes,
      rollId: 'roll',
      payload: const {},
      state: state,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  ];
}

void main() {
  testWidgets('More attention follows the active partition queue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = await boundSession();
    addTearDown(session.dispose);
    final changes = ValueNotifier(_pendingChange(OpState.conflict));
    addTearDown(changes.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(session),
          localStoreProvider.overrideWithValue(_MoreStore()),
          syncStatusProvider.overrideWithValue(const SyncStatus()),
          openOpsProvider.overrideWith((ref) async {
            changes.addListener(ref.invalidateSelf);
            ref.onDispose(() => changes.removeListener(ref.invalidateSelf));
            return changes.value;
          }),
          draftsProvider.overrideWith((_) async => []),
        ],
        child: const MaterialApp(home: MoreTab()),
      ),
    );
    await tester.pumpAndSettle();
    final attention = find.byIcon(Icons.error_outline);
    expect(attention, findsOneWidget);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNothing);

    changes.value = [];
    await tester.pumpAndSettle();
    expect(attention, findsNothing);
    for (final next in [
      binding(user: 'u2'),
      binding(host: 'http://server-b'),
    ]) {
      await session.bind(binding(), forToken: 't1');
      changes.value = _pendingChange(OpState.conflict);
      await tester.pumpAndSettle();
      expect(attention, findsOneWidget);

      await session.bind(next, forToken: 't1');
      await tester.pumpAndSettle();
      expect(attention, findsNothing);
    }
  });

  testWidgets('Sync returns to Settings and More or directly to Shooting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = await boundSession();
    addTearDown(session.dispose);
    final router = buildRouter(initialLocation: Routes.more, session: session);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          sessionStoreProvider.overrideWithValue(session),
          localStoreProvider.overrideWithValue(null),
          currentUserProvider.overrideWith(
            (_) async =>
                User.fromJson({'id': 'u1', 'email': 'account@example.com'}),
          ),
          openOpsProvider.overrideWith(
            (_) async => _pendingChange(OpState.pending),
          ),
          syncStatusProvider.overrideWithValue(const SyncStatus()),
          partitionsProvider.overrideWith((_) async => []),
          rollRepositoryProvider.overrideWithValue(FakeRollRepository()),
          cameraRepositoryProvider.overrideWithValue(FakeCameraRepository()),
          filmStockRepositoryProvider.overrideWithValue(
            FakeFilmStockRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    String location() =>
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(location(), Routes.settings);
    await tester.tap(find.byIcon(Icons.cloud_sync_outlined));
    await tester.pumpAndSettle();
    expect(location(), Routes.sync);
    router.pop();
    await tester.pumpAndSettle();
    expect(location(), Routes.settings);
    router.pop();
    await tester.pumpAndSettle();
    expect(location(), Routes.more);

    router.go(Routes.shooting);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.cloud_queue));
    await tester.pumpAndSettle();
    expect(location(), Routes.sync);
    router.pop();
    await tester.pumpAndSettle();
    expect(location(), Routes.shooting);
  });

  group('empty states share one card', () {
    testWidgets('expiry', (t) async {
      await pump(t, const ExpiryScreen());
      expect(find.byType(EmptyCard), findsOneWidget);
    });
    testWidgets('negatives at lab', (t) async {
      await pump(t, const NegativesAtLabScreen());
      expect(find.byType(EmptyCard), findsOneWidget);
    });
    testWidgets('labs', (t) async {
      await pump(t, const LabsScreen());
      expect(find.byType(EmptyCard), findsOneWidget);
      expect(find.text('No labs yet'), findsOneWidget);
    });
    testWidgets('film stocks, both segments', (t) async {
      await pump(t, const FilmTab());
      expect(find.byType(EmptyCard), findsOneWidget);
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      // The fake catalog has a stock, so the list shows instead.
      expect(find.byType(EmptyCard), findsNothing);
    });
    testWidgets('film stocks with an empty catalog', (t) async {
      await pump(t, const FilmTab(), stocks: FakeFilmStockRepository());
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      expect(find.text('No film stocks'), findsOneWidget);
    });
  });

  group('lists are cards, not plain list tiles', () {
    testWidgets('labs', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([lab('a', 'Foto Lab', address: 'Hanoi')]),
      );
      expect(find.byType(CardList), findsOneWidget);
      expect(find.text('Foto Lab'), findsOneWidget);
      expect(find.text('Hanoi'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
    testWidgets('a lab row names its scanners in the lab\'s order', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([
          lab('a', 'Foto Lab', scannerIds: ['s2', 's1']),
        ]),
        scanners: FakeScannerRepository([
          scanner('s1', 'Noritsu HS-1800'),
          scanner('s2', 'Frontier SP-3000'),
          scanner('s3', 'Epson V600'),
        ]),
      );
      expect(find.text('Frontier SP-3000, Noritsu HS-1800'), findsOneWidget);
    });
    testWidgets('a lab without scanners says so', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([lab('a', 'Foto Lab')]),
      );
      expect(find.text('No scanners'), findsOneWidget);
    });
    testWidgets('a lab without an address says so', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([lab('a', 'Foto Lab')]),
      );
      expect(find.text('No address'), findsOneWidget);
    });
    testWidgets('negatives at lab', (t) async {
      final p = FakeProcessingRepository()..atLab = [atLab()];
      await pump(t, const NegativesAtLabScreen(), processing: p);
      expect(find.byType(CardList), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Gold · Foto Lab'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
    });
    testWidgets('a late roll asks for a follow up', (t) async {
      final p = FakeProcessingRepository()..atLab = [atLab(days: 20)];
      await pump(t, const NegativesAtLabScreen(), processing: p);
      expect(find.textContaining('follow up?'), findsOneWidget);
    });
    testWidgets('film inventory and stocks', (t) async {
      final rolls = FakeRollRepository();
      await pump(t, const FilmTab(), rolls: rolls);
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      expect(find.byType(CardList), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Kodak Gold'), findsOneWidget);
    });
  });

  group('rolls are RollCards', () {
    testWidgets('expiry', (t) async {
      final rolls = FakeRollRepository()
        ..expiryView = ExpiryView.fromJson({
          'expiring': [
            {
              'roll': _rollJson('a'),
              'expiresOn': '2020-01-31',
              'expired': true,
            },
          ],
          'noExpiry': [_rollJson('b')],
        });
      await pump(t, const ExpiryScreen(), rolls: rolls);
      expect(find.byType(RollCard), findsNWidgets(2));
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('Labs and Film stocks follow the Gear layout', () {
    testWidgets('both use the tab header with a back button', (t) async {
      await pump(t, const LabsScreen());
      expect(find.byType(ScreenHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);

      await pump(t, const FilmTab());
      expect(find.byType(ScreenHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('the add label names the item while the list is empty', (
      t,
    ) async {
      await pump(t, const LabsScreen());
      expect(find.text('+ Lab'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('and says + Add once there is something', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([lab('a', 'Foto Lab')]),
      );
      expect(find.text('+ Add'), findsOneWidget);
      expect(find.text('+ Lab'), findsNothing);
    });

    testWidgets('film stocks: + Rolls, then + Add or + Stock by segment', (
      t,
    ) async {
      await pump(t, const FilmTab());
      expect(find.text('+ Rolls'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      expect(find.text('+ Add'), findsOneWidget);
    });

    testWidgets('an empty catalog offers + Stock', (t) async {
      await pump(t, const FilmTab(), stocks: FakeFilmStockRepository());
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      expect(find.text('+ Stock'), findsOneWidget);
    });

    testWidgets('rows are the same size as Gear rows', (t) async {
      await pump(
        t,
        const LabsScreen(),
        labs: FakeLabRepository([lab('a', 'Foto Lab')]),
      );
      final tile = t.widget<CardTile>(find.byType(CardTile));
      expect(tile.iconSize, 44);
      expect(tile.compact, isFalse);
      expect(
        tile.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    });

    testWidgets('film rows are the same size as Gear rows', (t) async {
      await pump(t, const FilmTab());
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      final tile = t.widget<CardTile>(find.byType(CardTile));
      expect(tile.iconSize, 44);
      expect(tile.compact, isFalse);
    });
  });

  group('forms use the shared form kit', () {
    testWidgets('settings', (t) async {
      await pump(t, const SettingsScreen());
      expect(find.text('SAVED SERVERS'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('film filters light up when set', (t) async {
      await pump(t, const FilmTab());
      expect(find.byType(FilterPill), findsNWidgets(3));
      await t.tap(find.text('TYPE'));
      await t.pumpAndSettle();
      await t.tap(find.text('COLOR'));
      await t.pumpAndSettle();
      final set = find.byWidgetPredicate(
        (w) => w is FilterPill && w.label == 'color' && w.on,
      );
      expect(set, findsOneWidget);
    });
  });
}

Map<String, dynamic> _rollJson(String id) => {
  'id': id,
  'filmStockId': 's1',
  'stockBrand': 'Kodak',
  'stockName': 'Gold',
  'format': 135,
  'exposures': 36,
  'status': 'in_stock',
};
