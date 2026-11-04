import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/routing/router.dart';
import 'package:meta_frames/routing/routes.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';

import '../../testing/fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  required FakeLabOrderRepository orders,
  FakeProcessingRepository? processing,
  String? push,
}) async {
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.orders);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labOrderRepositoryProvider.overrideWithValue(orders),
        labRepositoryProvider.overrideWithValue(
          FakeLabRepository([
            Lab.fromJson({'id': 'b1', 'name': 'Lab A'}),
          ]),
        ),
        processingRepositoryProvider.overrideWithValue(
          processing ?? FakeProcessingRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (push != null) {
    router.push(push);
    await tester.pumpAndSettle();
  }
  return router;
}

String _location(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

Finder _field(String label) => find.ancestor(
  of: find.text(label.toUpperCase()),
  matching: find.byType(Column),
);

Finder _input(String label) =>
    find.descendant(of: _field(label).first, matching: find.byType(TextField));

CheckboxListTile _tick(WidgetTester tester, String title) =>
    tester.widget(find.widgetWithText(CheckboxListTile, title));

void main() {
  group('model', () {
    test('counts one roll on two lines once', () {
      final job = orderJob('j1');
      final order = labOrder(
        'o1',
        lines: [
          orderLine('develop', 'Develop', 60000, jobs: [job]),
          orderLine('scan', 'Scan', 40000, jobs: [job]),
        ],
      );
      expect(order.rolls, 1);
      expect(order.takenPlaces, 2);
      expect(order.billedPlaces, 2);
      expect(order.jobs.single.lines.map((l) => l.product), [
        'Develop',
        'Scan',
      ]);
      expect(order.lines.first.unitCost, 66000);
      expect(order.lines.first.room, 0);
    });
  });

  group('list and detail', () {
    testWidgets('lists an order and opens it', (tester) async {
      final router = await _pump(
        tester,
        orders: FakeLabOrderRepository([labOrder('o1')]),
      );
      expect(find.text('#0510006'), findsOneWidget);
      await tester.tap(find.text('#0510006'));
      await tester.pumpAndSettle();
      expect(_location(router), Routes.order('o1'));
      expect(find.text('Develop'), findsOneWidget);
      expect(
        find.textContaining('${fmtVnd(66000)} each with VAT'),
        findsOneWidget,
      );
      expect(find.text('No rolls on this order yet.'), findsOneWidget);
    });

    testWidgets('shows a roll on two lines once and takes it off', (
      tester,
    ) async {
      final job = orderJob('j1');
      final processing = FakeProcessingRepository();
      await _pump(
        tester,
        orders: FakeLabOrderRepository([
          labOrder(
            'o1',
            lines: [
              orderLine('develop', 'Develop', 60000, jobs: [job]),
              orderLine('scan', 'Scan', 40000, jobs: [job]),
            ],
          ),
        ]),
        processing: processing,
        push: Routes.order('o1'),
      );
      expect(find.text('Kodak Gold'), findsOneWidget);
      expect(find.textContaining('Develop + Scan'), findsOneWidget);

      await tester.tap(find.byTooltip('Take Kodak Gold off this order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take off'));
      await tester.pumpAndSettle();
      expect(processing.orderLines['j1'], isEmpty);
    });

    testWidgets('deletes an order and closes', (tester) async {
      final orders = FakeLabOrderRepository([labOrder('o1')]);
      final router = await _pump(
        tester,
        orders: orders,
        push: Routes.order('o1'),
      );
      await tester.tap(find.text('Delete order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(orders.deleted, ['o1']);
      expect(_location(router), Routes.orders);
    });
  });

  group('add roll', () {
    testWidgets('says so when no roll is waiting', (tester) async {
      await _pump(
        tester,
        orders: FakeLabOrderRepository([labOrder('o1')]),
        push: Routes.orderAddRoll('o1'),
      );
      expect(find.text('No roll is waiting for an order'), findsOneWidget);
      expect(find.text('Add roll'), findsNothing);
    });

    testWidgets('puts one roll on two lines and shows the price', (
      tester,
    ) async {
      final orders = FakeLabOrderRepository([labOrder('o1')])
        ..linkable = [LabOrderJob.fromJson(orderJob('j1'))];
      final processing = FakeProcessingRepository();
      final router = await _pump(
        tester,
        orders: orders,
        processing: processing,
        push: Routes.orderAddRoll('o1', lineId: 'develop'),
      );
      expect(_tick(tester, 'Develop (0 of 1)').value, isTrue);
      expect(_tick(tester, 'Scan (0 of 1)').value, isFalse);

      await tester.tap(find.text('Add roll'));
      await tester.pumpAndSettle();
      expect(find.text('Select a roll.'), findsOneWidget);
      expect(processing.orderLines, isEmpty);

      await tester.tap(find.text('Select a roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kodak Gold').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan (0 of 1)'));
      await tester.pumpAndSettle();
      expect(find.text(fmtVnd(110000)), findsOneWidget);

      await tester.tap(find.text('Add roll'));
      await tester.pumpAndSettle();
      expect(processing.orderLines['j1'], ['develop', 'scan']);
      expect(_location(router), Routes.orders);
    });

    testWidgets('keeps the lines a roll is on, even a full one', (
      tester,
    ) async {
      final job = orderJob('j1');
      final orders =
          FakeLabOrderRepository([
              labOrder(
                'o1',
                lines: [
                  orderLine('develop', 'Develop', 60000, jobs: [job]),
                  orderLine('scan', 'Scan', 40000),
                ],
              ),
            ])
            ..linkable = [
              LabOrderJob.fromJson(orderJob('j1', lineIds: ['develop'])),
            ];
      await _pump(tester, orders: orders, push: Routes.orderAddRoll('o1'));
      // Full, and no roll chosen yet: it cannot be ticked.
      expect(_tick(tester, 'Develop (1 of 1)').onChanged, isNull);

      await tester.tap(find.text('Select a roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kodak Gold').last);
      await tester.pumpAndSettle();
      final own = _tick(tester, 'Develop (1 of 1)');
      expect(own.value, isTrue);
      expect(own.onChanged, isNotNull);
      expect(_tick(tester, 'Scan (0 of 1)').value, isTrue);
    });
  });

  group('form', () {
    testWidgets('asks for the lab and saves the lines', (tester) async {
      final orders = FakeLabOrderRepository();
      await _pump(tester, orders: orders, push: Routes.orderNew);

      await tester.enterText(_input('Order code *'), '#0510006');
      await tester.enterText(_input('Product *'), '35mm Colour');
      await tester.enterText(_input('Qty *'), '3');
      await tester.enterText(_input('Unit price *'), '145000');
      await tester.enterText(_input('VAT (optional)'), '34800');
      await tester.pump();
      expect(find.text('Total ${fmtVnd(469800)}'), findsOneWidget);

      await tester.tap(find.text('Add order'));
      await tester.pumpAndSettle();
      expect(find.text('Select a lab.'), findsOneWidget);
      expect(orders.saved, isNull);

      await tester.tap(find.text('Select a lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add order'));
      await tester.pumpAndSettle();

      final saved = orders.saved!;
      expect(saved.code, '0510006');
      expect(saved.vat, 34800);
      expect(saved.lines.single.quantity, 3);
      expect(saved.toJson()['items'], [saved.lines.single.toJson()]);
    });

    testWidgets('keeps a line with rolls and its lab', (tester) async {
      final job = orderJob('j1');
      final orders = FakeLabOrderRepository([
        labOrder(
          'o1',
          lines: [
            orderLine('develop', 'Develop', 60000, jobs: [job]),
            orderLine('scan', 'Scan', 40000),
          ],
        ),
      ]);
      await _pump(tester, orders: orders, push: Routes.orderEdit('o1'));
      expect(find.text('LAB (LOCKED)'), findsOneWidget);
      final remove = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline).first,
      );
      expect(remove.onPressed, isNull);
      final other = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline).last,
      );
      expect(other.onPressed, isNotNull);
    });
  });
}
