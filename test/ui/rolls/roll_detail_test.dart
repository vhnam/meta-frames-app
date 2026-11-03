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

const _name = 'Fujifilm Fujicolor Superia X-TRA 400 Respooled Long Name';
const _base = 'Kodak Vision3 500T Remjet Removed Long Name';

Map<String, dynamic> _stock(String id, String name) => {
  'id': id,
  'brand': name.split(' ').first,
  'name': name.split(' ').skip(1).join(' '),
  'type': 'color',
  'boxIso': '400',
  'process': 'C-41',
  'packaging': 'factory',
};

class _Rolls extends FakeRollRepository {
  _Rolls({required this.withBase});
  final bool withBase;

  @override
  Future<RollDetail> roll(String id) async => RollDetail.fromJson({
    'roll': {
      'id': id,
      'filmStockId': 's1',
      'stockBrand': 'Fujifilm',
      'stockName': 'Superia',
      'format': 135,
      'exposures': 36,
      'status': 'done_shooting',
    },
    'stock': _stock('s1', _name),
    if (withBase) 'baseStock': _stock('s2', _base),
    'totals': {
      'rollPrice': 0,
      'processingPrice': 0,
      'total': 0,
      'incomplete': false,
    },
  });
}

/// Opens the roll's page at the width of a narrow phone.
Future<GoRouter> _pump(WidgetTester tester, {bool withBase = true}) async {
  tester.view
    ..physicalSize = const Size(360, 2000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.roll('r'));
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rollRepositoryProvider.overrideWithValue(_Rolls(withBase: withBase)),
        filmStockRepositoryProvider.overrideWithValue(
          FakeFilmStockRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _inCard(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

void main() {
  testWidgets('the status sits under the names, in that order', (tester) async {
    await _pump(tester);
    final name = tester.getTopLeft(_inCard(_name));
    final base = tester.getTopLeft(_inCard('Base: $_base'));
    final status = tester.getTopLeft(find.byType(StatusChip));
    expect(name.dy, lessThan(base.dy));
    expect(base.dy, lessThan(status.dy));
    expect(status.dx, name.dx);
  });

  testWidgets('a long name has the width of the card and is not cut', (
    tester,
  ) async {
    await _pump(tester);
    // 360 wide, less 16 page, 16 card padding each side, chevron and its gap.
    expect(tester.getSize(_inCard(_name)).width, greaterThan(250));
    final title = tester.widget<Text>(_inCard(_name));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a base stock it shows the speed and process', (
    tester,
  ) async {
    await _pump(tester, withBase: false);
    expect(_inCard('ISO 400 · C-41'), findsOneWidget);
  });

  testWidgets('the row opens the stock', (tester) async {
    final router = await _pump(tester);
    await tester.tap(_inCard(_name));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      Routes.stock('s1'),
    );
  });
}
