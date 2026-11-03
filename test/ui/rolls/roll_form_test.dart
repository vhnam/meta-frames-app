import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/rolls/widgets/roll_form.dart';

import '../../testing/fakes.dart';

class _RecordingRolls extends FakeRollRepository {
  _RecordingRolls() : super(const []);
  RollEdit? edited;

  @override
  Future<RollDetail> update(String id, RollEdit edit) async {
    edited = edit;
    return rollDetail(id);
  }
}

RollDetail _detail({int format = 135, String status = 'done_shooting'}) =>
    RollDetail.fromJson({
      'roll': {
        'id': 'r1',
        'filmStockId': 's1',
        'stockBrand': 'Kodak',
        'stockName': 'Gold',
        'format': format,
        'exposures': 36,
        'status': status,
        'shotIso': 800,
        'price': 150000,
        'expiry': {'year': 2027, 'month': 6},
        'description': 'Pushed two stops',
        'startedAt': '2026-03-05',
        'finishedAt': '2026-03-20',
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
    });

Future<_RecordingRolls> _pump(WidgetTester tester, RollDetail detail) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rolls = _RecordingRolls();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, _) => RollFormScreen(detail: detail),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rollRepositoryProvider.overrideWithValue(rolls)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/edit');
  await tester.pumpAndSettle();
  return rolls;
}

void main() {
  testWidgets('edits the film, price and expiry only', (tester) async {
    await _pump(tester, _detail());

    expect(find.text('Edit Roll'), findsOneWidget);
    for (final label in [
      'FORMAT *',
      'EXPOSURES *',
      'UNIT PRICE (OPTIONAL)',
      'EXPIRY YEAR (OPTIONAL)',
      'EXPIRY MONTH (OPTIONAL)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in [
      'SHOT ISO (OPTIONAL)',
      'START DATE',
      'FINISH DATE',
      'NOTES (OPTIONAL)',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('220'), findsNothing);
  });

  testWidgets('groups the fields in numbered sections, as on the dashboard', (
    tester,
  ) async {
    await _pump(tester, _detail());

    for (final (number, title, note) in [
      ('01', 'FILM', '* Required attributes'),
      ('02', 'PURCHASE', 'Shipping excluded'),
      ('03', 'EXPIRY', 'As printed on the box'),
    ]) {
      expect(find.text(number), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text(note), findsOneWidget);
    }
    final film = tester.getTopLeft(find.text('FILM')).dy;
    final purchase = tester.getTopLeft(find.text('PURCHASE')).dy;
    final expiry = tester.getTopLeft(find.text('EXPIRY')).dy;
    expect(film, lessThan(purchase));
    expect(purchase, lessThan(expiry));
  });

  testWidgets('expiry year and month stack at full width, in line', (
    tester,
  ) async {
    await _pump(tester, _detail());

    final year = find.byType(TextFormField).last;
    final month = find.byType(DropdownButtonFormField<int?>);
    expect(tester.getTopLeft(month).dx, tester.getTopLeft(year).dx);
    expect(tester.getSize(month).width, tester.getSize(year).width);
    expect(
      tester.getTopLeft(month).dy,
      greaterThan(tester.getTopLeft(year).dy),
    );
    expect(find.text('June'), findsOneWidget);
  });

  testWidgets('the expiry month uses the text field\'s font', (tester) async {
    await _pump(tester, _detail());

    final dropdown = tester.widget<DropdownButton<int?>>(
      find.byType(DropdownButton<int?>),
    );
    final context = tester.element(find.byType(DropdownButton<int?>));
    expect(dropdown.style, Theme.of(context).textTheme.bodyLarge);
  });

  testWidgets('a quick pick fills the exposures and saves', (tester) async {
    final rolls = await _pump(tester, _detail());

    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(rolls.edited?.exposures, 24);
  });

  testWidgets('film stock is locked once the roll left stock', (tester) async {
    await _pump(tester, _detail());
    expect(find.text('FILM STOCK (LOCKED)'), findsOneWidget);
    expect(
      find.text('Film stock can only be changed while the roll is In Stock.'),
      findsOneWidget,
    );
  });

  testWidgets('a roll out of stock has no delete action', (tester) async {
    await _pump(tester, _detail());
    expect(find.text('Delete roll'), findsNothing);
  });

  testWidgets('a roll in stock can be deleted', (tester) async {
    await _pump(tester, _detail(status: 'in_stock'));
    expect(find.text('FILM STOCK *'), findsOneWidget);
    expect(find.text('Delete roll'), findsOneWidget);
  });

  group('deleting from Edit Roll', () {
    Future<(GoRouter, FakeRollRepository)> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(800, 3000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rolls = FakeRollRepository();
      final router = buildRouter(initialLocation: Routes.rolls);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rollRepositoryProvider.overrideWithValue(rolls),
            filmStockRepositoryProvider.overrideWithValue(
              FakeFilmStockRepository(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push(Routes.roll('r'));
      await tester.pumpAndSettle();
      return (router, rolls);
    }

    testWidgets('the details screen has no delete action', (tester) async {
      await open(tester);
      expect(find.text('Load into camera'), findsOneWidget);
      expect(find.text('Delete roll'), findsNothing);
    });

    testWidgets('cancelling keeps the roll', (tester) async {
      final (_, rolls) = await open(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rolls.calls, isEmpty);
      expect(find.text('Edit Roll'), findsOneWidget);
    });

    testWidgets('returns past the deleted roll\'s details', (tester) async {
      final (router, rolls) = await open(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(rolls.calls, ['delete:r']);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        Routes.rolls,
      );
    });
  });

  testWidgets('keeps a saved format outside the list', (tester) async {
    await _pump(tester, _detail(format: 220));

    expect(find.text('220'), findsOneWidget);
  });

  testWidgets('saving keeps the fields this form does not edit', (
    tester,
  ) async {
    final rolls = await _pump(tester, _detail());

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(rolls.edited?.toJson(), {
      'filmStockId': 's1',
      'format': 135,
      'exposures': 36,
      'price': 150000,
      'expiry': {'year': 2027, 'month': 6},
      'shotIso': 800,
      'startedAt': '2026-03-05',
      'finishedAt': '2026-03-20',
      'description': 'Pushed two stops',
    });
  });
}
