import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/widgets/add_rolls.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/fakes.dart';

class _RecordingRolls extends FakeRollRepository {
  _RecordingRolls() : super(const []);
  NewRolls? added;

  @override
  Future<List<RollSummary>> addRolls(
    NewRolls rolls, {
    String? idempotencyKey,
  }) async {
    added = rolls;
    return super.addRolls(rolls, idempotencyKey: idempotencyKey);
  }
}

Future<_RecordingRolls> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rolls = _RecordingRolls();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => AddRollsScreen(stock: stock('s1')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        rollRepositoryProvider.overrideWithValue(rolls),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/new');
  await tester.pumpAndSettle();
  return rolls;
}

Future<void> _chooseMay(WidgetTester tester) async {
  await tester.tap(find.text('Unknown'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('May').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers the dashboard formats', (tester) async {
    await _pump(tester);

    for (final format in ['135', '120', '110']) {
      expect(find.text(format), findsOneWidget);
    }
    for (final format in ['220', '127']) {
      expect(find.text(format), findsNothing);
    }
  });

  testWidgets('typed values fill the save label and the request', (
    tester,
  ) async {
    final rolls = await _pump(tester);

    expect(find.byType(ChoiceChip), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '24');
    await tester.enterText(fields.at(1), '10');
    await tester.pump();
    await tester.tap(find.text('Add 10 rolls'));
    await tester.pumpAndSettle();

    expect(rolls.added?.exposures, 24);
    expect(rolls.added?.quantity, 10);
  });

  testWidgets('saves without a year, and a month waits for one', (
    tester,
  ) async {
    final rolls = await _pump(tester);

    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();
    expect(find.text('May'), findsNothing);

    await tester.tap(find.text('Add roll'));
    await tester.pumpAndSettle();

    expect(rolls.added, isNotNull);
    expect(rolls.added?.toJson().containsKey('expiry'), isFalse);
  });

  for (final year in ['19664', '1899', '2101', 'abc']) {
    testWidgets('rejects the expiry year $year', (tester) async {
      final rolls = await _pump(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Year'), year);
      await tester.pump();
      await tester.tap(find.text('Add roll'));
      await tester.pumpAndSettle();

      expect(find.text('1900 to 2100'), findsOneWidget);
      expect(rolls.added, isNull);
    });
  }

  testWidgets('accepts the last expiry year', (tester) async {
    final rolls = await _pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Year'), '2100');
    await tester.pump();
    await tester.tap(find.text('Add roll'));
    await tester.pumpAndSettle();

    expect(rolls.added?.toJson()['expiry'], {'year': 2100});
  });

  testWidgets('saves the expiry in the shape the API reads', (tester) async {
    final rolls = await _pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Year'), '1900');
    await tester.pump();
    await _chooseMay(tester);
    await tester.tap(find.text('Add roll'));
    await tester.pumpAndSettle();

    expect(rolls.added?.toJson()['expiry'], {'year': 1900, 'month': 5});
  });
}
