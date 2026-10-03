import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/core/widgets/cards.dart';
import 'package:meta_frames/ui/film/widgets/film_tab.dart';
import 'package:meta_frames/ui/labs/widgets/labs_screen.dart';
import 'package:meta_frames/ui/labs/widgets/negatives_at_lab.dart';
import 'package:meta_frames/ui/more/widgets/more_tab.dart';
import 'package:meta_frames/ui/more/widgets/search_screen.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:meta_frames/ui/rolls/widgets/expiry_screen.dart';
import 'package:meta_frames/ui/rolls/widgets/roll_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../testing/fakes.dart';

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  FakeRollRepository? rolls,
  FakeLabRepository? labs,
  FakeProcessingRepository? processing,
  FakeFilmStockRepository? stocks,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        rollRepositoryProvider.overrideWithValue(rolls ?? FakeRollRepository()),
        labRepositoryProvider.overrideWithValue(labs ?? FakeLabRepository()),
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

void main() {
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
    testWidgets('search finds nothing', (t) async {
      await pump(t, const SearchScreen());
      await t.enterText(find.byType(TextField), 'nothing');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.byType(EmptyCard), findsOneWidget);
      expect(find.text('No rolls found'), findsOneWidget);
    });
  });

  group('lists are cards, not plain list tiles', () {
    testWidgets('more tab', (t) async {
      await pump(t, const MoreTab());
      expect(find.byType(CardList), findsOneWidget);
      expect(find.byType(CardTile), findsNWidgets(6));
      expect(find.byType(ListTile), findsNothing);
    });
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
    testWidgets('search results', (t) async {
      await pump(
        t,
        const SearchScreen(),
        rolls: FakeRollRepository([roll('a'), roll('b')]),
      );
      await t.enterText(find.byType(TextField), 'gold');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.byType(RollCard), findsNWidgets(2));
    });
  });

  group('add actions sit in the app bar', () {
    testWidgets('labs has + Add and no floating button', (t) async {
      await pump(t, const LabsScreen());
      expect(find.text('+ Add'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
    testWidgets('film stocks switches between + Rolls and + Stock', (t) async {
      await pump(t, const FilmTab());
      expect(find.text('+ Rolls'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await t.tap(find.text('Stocks'));
      await t.pumpAndSettle();
      expect(find.text('+ Stock'), findsOneWidget);
    });
  });

  group('forms use the shared form kit', () {
    testWidgets('settings', (t) async {
      await pump(t, const SettingsScreen());
      expect(find.text('SERVER URL'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(
        find.textContaining('Android emulator reaches the host machine'),
        findsOneWidget,
      );
    });
    testWidgets('the lab dialog labels its fields', (t) async {
      await pump(t, const LabsScreen());
      await t.tap(find.text('+ Add'));
      await t.pumpAndSettle();
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('ADDRESS (OPTIONAL)'), findsOneWidget);
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
