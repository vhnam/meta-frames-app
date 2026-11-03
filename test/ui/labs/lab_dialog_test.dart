import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/labs/widgets/lab_dialog.dart';

import '../../testing/fakes.dart';

final _catalog = [
  scanner('s1', 'Noritsu HS-1800', builtIn: true),
  scanner('s2', 'Frontier SP-3000', builtIn: true),
  scanner('s3', 'Epson V600'),
];

Future<FakeLabRepository> _open(WidgetTester tester, [Lab? existing]) async {
  final labs = FakeLabRepository([?existing]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(labs),
        scannerRepositoryProvider.overrideWithValue(
          FakeScannerRepository(_catalog),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => editLab(context, existing),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return labs;
}

Finder _checkbox(String scannerName) => find.descendant(
  of: find
      .ancestor(of: find.text(scannerName), matching: find.byType(Row))
      .first,
  matching: find.byType(Checkbox),
);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers every scanner, ticking only the lab\'s', (tester) async {
    await _open(tester, lab('a', 'Foto Lab', scannerIds: ['s3']));
    expect(find.text('Noritsu HS-1800'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(tester.widget<Checkbox>(_checkbox('Epson V600')).value, isTrue);
    expect(
      tester.widget<Checkbox>(_checkbox('Noritsu HS-1800')).value,
      isFalse,
    );
    // Only a ticked scanner can be the default.
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('ticked scanners come first, in the lab\'s order', (
    tester,
  ) async {
    await _open(tester, lab('a', 'Foto Lab', scannerIds: ['s3', 's2']));
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('Epson V600'), lessThan(y('Frontier SP-3000')));
    expect(y('Frontier SP-3000'), lessThan(y('Noritsu HS-1800')));
  });

  testWidgets('a new lab saves the ticked scanners without a default', (
    tester,
  ) async {
    final labs = await _open(tester);
    await tester.enterText(find.byType(TextField).first, 'Foto Lab');
    await tester.tap(_checkbox('Frontier SP-3000'));
    await tester.pump();
    await tester.tap(_checkbox('Noritsu HS-1800'));
    await tester.pump();
    await _save(tester);
    expect(labs.saved!.scannerIds, ['s2', 's1']);
    expect(labs.saved!.defaultScannerId, isNull);
  });

  testWidgets('making a scanner the default moves it to the top', (
    tester,
  ) async {
    final labs = await _open(
      tester,
      lab('a', 'Foto Lab', scannerIds: ['s1', 's2']),
    );
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await _save(tester);
    expect(labs.saved!.scannerIds, ['s2', 's1']);
    expect(labs.saved!.defaultScannerId, 's2');
  });

  testWidgets('switching the default off keeps the scanner', (tester) async {
    final labs = await _open(
      tester,
      lab('a', 'Foto Lab', scannerIds: ['s1'], defaultScannerId: 's1'),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await _save(tester);
    expect(labs.saved!.scannerIds, ['s1']);
    expect(labs.saved!.defaultScannerId, isNull);
  });

  testWidgets('unticking the default clears it too', (tester) async {
    final labs = await _open(
      tester,
      lab('a', 'Foto Lab', scannerIds: ['s1', 's2'], defaultScannerId: 's1'),
    );
    await tester.tap(_checkbox('Noritsu HS-1800'));
    await tester.pump();
    await _save(tester);
    expect(labs.saved!.scannerIds, ['s2']);
    expect(labs.saved!.defaultScannerId, isNull);
  });

  testWidgets('saving without changes keeps scanners and default', (
    tester,
  ) async {
    final labs = await _open(
      tester,
      lab('a', 'Foto Lab', scannerIds: ['s2', 's1'], defaultScannerId: 's1'),
    );
    await _save(tester);
    expect(labs.saved!.scannerIds, ['s2', 's1']);
    expect(labs.saved!.defaultScannerId, 's1');
  });

  testWidgets('fits a small phone with long names', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, lab('a', 'Foto Lab', scannerIds: ['s1', 's2', 's3']));
    expect(tester.takeException(), isNull);
  });
}
