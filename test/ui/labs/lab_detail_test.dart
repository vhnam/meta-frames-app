import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/core/widgets/common.dart';
import 'package:meta_frames/ui/labs/widgets/lab_detail.dart';

import '../../testing/fakes.dart';

final _catalog = [
  scanner('s1', 'Noritsu HS-1800', kind: 'minilab', builtIn: true),
  scanner('s2', 'Frontier SP-3000', kind: 'minilab', builtIn: true),
  scanner('s3', 'Epson V600', kind: 'flatbed'),
  scanner('s4', 'Not at this lab', kind: 'drum'),
];

Future<void> _pump(WidgetTester tester, Lab lab) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(FakeLabRepository([lab])),
        scannerRepositoryProvider.overrideWithValue(
          FakeScannerRepository(_catalog),
        ),
      ],
      child: MaterialApp(home: LabDetailScreen(labId: lab.id)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the name and address', (tester) async {
    await _pump(tester, lab('a', 'Foto Lab', address: 'Hanoi'));
    expect(find.text('Name'), findsOneWidget);
    // The app bar title and the Name row.
    expect(find.text('Foto Lab'), findsNWidgets(2));
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Hanoi'), findsOneWidget);
  });

  testWidgets('says when there is no address and no scanners', (tester) async {
    await _pump(tester, lab('a', 'Foto Lab'));
    expect(find.text('No address'), findsOneWidget);
    expect(find.text('No scanners'), findsOneWidget);
  });

  testWidgets('lists only the lab\'s scanners, in the lab\'s order', (
    tester,
  ) async {
    await _pump(tester, lab('a', 'Foto Lab', scannerIds: ['s3', 's1']));
    expect(find.text('Not at this lab'), findsNothing);
    expect(find.text('Frontier SP-3000'), findsNothing);
    final own = tester.getTopLeft(find.text('Epson V600'));
    final builtIn = tester.getTopLeft(find.text('Noritsu HS-1800'));
    expect(own.dy, lessThan(builtIn.dy));
    expect(find.text('Flatbed · Yours'), findsOneWidget);
    expect(find.text('Lab minilab'), findsOneWidget);
  });

  testWidgets('marks only the default scanner', (tester) async {
    await _pump(
      tester,
      lab('a', 'Foto Lab', scannerIds: ['s1', 's2'], defaultScannerId: 's1'),
    );
    expect(find.byType(StampBadge), findsOneWidget);
    expect(find.text('DEFAULT'), findsOneWidget);
  });

  testWidgets('a lab without a default marks nothing', (tester) async {
    await _pump(tester, lab('a', 'Foto Lab', scannerIds: ['s1']));
    expect(find.byType(StampBadge), findsNothing);
  });

  testWidgets('Edit opens the lab dialog with the lab filled in', (
    tester,
  ) async {
    await _pump(tester, lab('a', 'Foto Lab', address: 'Hanoi'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit lab'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Foto Lab'), findsOneWidget);
  });

  testWidgets('Delete asks first', (tester) async {
    await _pump(tester, lab('a', 'Foto Lab'));
    await tester.tap(find.text('Delete lab'));
    await tester.pumpAndSettle();
    expect(find.text('Delete lab?'), findsOneWidget);
  });
}
