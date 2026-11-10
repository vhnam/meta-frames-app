import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_frames/data/services/api_client.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/domain/models/roll_requests.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/rolls/widgets/roll_form.dart';

import '../../testing/fakes.dart';

Map<String, dynamic> _json({
  required int version,
  String? description,
  int price = 150000,
}) => {
  'roll': {
    'id': 'r1',
    'filmStockId': 's1',
    'stockBrand': 'Kodak',
    'stockName': 'Gold',
    'format': 135,
    'exposures': 36,
    'status': 'done_shooting',
    'shotIso': 800,
    'price': price,
    'description': description,
    'startedAt': '2026-03-05',
    'finishedAt': '2026-03-20',
    'version': version,
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
};

/// The server's roll, which moved on (a note synced from the phone) after
/// the form opened at version 4.
class _Server extends FakeRollRepository {
  _Server() : super(const []);
  var current = _json(version: 5, description: 'Synced from the phone');
  final edits = <(RollEdit, int?)>[];

  @override
  Future<RollDetail> roll(String id) async => RollDetail.fromJson(current);

  @override
  Future<RollDetail> update(String id, RollEdit edit, {int? version}) async {
    edits.add((edit, version));
    if (version != current['roll']['version']) {
      throw ApiException(412, 'roll_changed', 'The roll changed');
    }
    return RollDetail.fromJson(current);
  }
}

Future<_Server> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final server = _Server();
  final opened = RollDetail.fromJson(
    _json(version: 4, description: 'Hanoi trip'),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, _) => RollFormScreen(detail: opened),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rollRepositoryProvider.overrideWithValue(server)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/edit');
  await tester.pumpAndSettle();
  return server;
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a refused edit keeps what was typed until the user chooses', (
    tester,
  ) async {
    final server = await _pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '150000'),
      '180000',
    );
    await _save(tester);

    expect(server.edits.single.$2, 4, reason: 'sent with the loaded version');
    expect(find.widgetWithText(TextFormField, '180000'), findsOneWidget);

    // Nothing is sent again until the user picks.
    await _save(tester);
    expect(server.edits, hasLength(1));

    await tester.tap(find.text('Keep my edits'));
    await tester.pumpAndSettle();
    await _save(tester);

    final (edit, version) = server.edits.last;
    expect(version, 5);
    expect(edit.price, 180000);
    expect(
      edit.description,
      'Synced from the phone',
      reason: 'the note saved since is kept, not reverted',
    );
  });

  testWidgets('"Use the current values" takes the roll as it is now', (
    tester,
  ) async {
    final server = await _pump(tester);
    server.current = _json(version: 5, description: 'x', price: 99000);
    await tester.enterText(
      find.widgetWithText(TextFormField, '150000'),
      '180000',
    );
    await _save(tester);
    await tester.tap(find.text('Use the current values'));
    await tester.pumpAndSettle();
    await _save(tester);

    final (edit, version) = server.edits.last;
    expect(version, 5);
    expect(edit.price, 99000);
  });
}
